# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Orchestrates one item extraction:
    #   document -> pages -> chunk around the item -> prompt -> LLM -> parse ->
    #   fill provenance -> validate against rulebook/schema.json -> write item -> changelog.
    # Schema-invalid output is never written to the rulebook; it goes to rejects_dir.
    class Extractor
      Result = Data.define(:item_id, :path, :data, :pages, :model)

      MODES = %w[auto text pdf].freeze

      def initialize(doc:, doc_id:, llm:, out_dir:, instrument: "MDS-3.0", mode: "auto", window: 2, force: false,
                     hint: nil, conventions: [], template: PromptTemplate.default, changelog: nil,
                     rejects_dir: Rails.root.join("tmp/rulebook_rejects"), shell: Shell.new, logger: nil)
        raise Error, "MODE must be one of #{MODES.join(', ')}" unless MODES.include?(mode)

        @source = TextSource.new(doc, shell: shell)
        @doc_id = doc_id
        @instrument = instrument
        @llm = llm
        @out_dir = Pathname(out_dir)
        @mode = mode
        @window = window
        @force = force
        @hint = hint # optional one-line description for ids that name no literal item (CONV-*)
        @conventions = conventions # [{"rule", "source"}] from this instrument's CONV items; subordinate to item pages
        @template = template
        # The changelog lives beside the items directory, so smoke runs into tmp/ never touch rulebook/changelog.md.
        @changelog = changelog || Changelog.new(@out_dir.parent.join("changelog.md"))
        @rejects_dir = Pathname(rejects_dir)
        @logger = logger
      end

      # Renders the prompt without calling the model (DRY_RUN).
      def prompt_for(item_id)
        prepare(item_id).first
      end

      def run(item_id)
        target = @out_dir.join("#{item_id}.json")
        raise AlreadyExists, "#{target} exists; pass FORCE=1 to overwrite" if target.exist? && !@force

        prompt, selection, pdf = prepare(item_id)
        log "#{item_id}: #{pdf ? 'PDF mode (document attached)' : "text mode, pages #{selection.numbers.join(',')}"}, model #{@llm.model}"

        response = @llm.complete(system: prompt.system, user: prompt.user, output_schema: OutputSchema.build,
                                 pdf: pdf, pdf_title: @doc_id)
        log "#{item_id}: usage #{response.usage.inspect}"
        data = finalize(item_id, parse(item_id, response.text), response.model)
        validate!(item_id, data)

        @out_dir.mkpath
        target.write(JSON.pretty_generate(data) + "\n")
        @changelog.append(action: "extract", item_id: item_id, doc: @doc_id, model: response.model,
                          pages: selection&.numbers, note: "written to #{relative(target)}")
        log "#{item_id}: wrote #{relative(target)}"
        Result.new(item_id: item_id, path: target, data: data, pages: selection&.numbers, model: response.model)
      end

      private

      def prepare(item_id)
        if use_pdf?
          prompt = @template.render(item_id: item_id, instrument: @instrument, doc_id: @doc_id, hint: @hint, conventions: @conventions,
                                    pages_text: nil, attachment: true, output_schema_json: schema_json)
          [ prompt, nil, @source.pdf_bytes ]
        else
          selection = Chunker.new(@source.pages, window: @window).select(item_id)
          prompt = @template.render(item_id: item_id, instrument: @instrument, doc_id: @doc_id, hint: @hint, conventions: @conventions,
                                    pages_text: Chunker.render(selection.pages), attachment: false,
                                    output_schema_json: schema_json)
          [ prompt, selection, nil ]
        end
      end

      def use_pdf?
        case @mode
        when "pdf" then true
        when "text" then false
        else @source.kind == :pdf && @source.looks_scanned?
        end
      end

      def schema_json
        @schema_json ||= JSON.pretty_generate(OutputSchema.build)
      end

      def parse(item_id, text)
        JSON.parse(strip_fences(text))
      rescue JSON::ParserError => e
        raise Rejected.new(item_id, [ "model output is not valid JSON: #{e.message}" ], save_reject(item_id, text))
      end

      def strip_fences(text)
        text.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
      end

      def finalize(item_id, payload, model)
        data = restore_required_nulls(compact(payload))
        data["item_id"] ||= item_id
        data["instrument"] ||= @instrument
        data["provenance_summary"] = {
          "extracted_at" => Date.today.iso8601,
          "model" => model,
          "extractor_version" => VERSION,
          "expert_review_status" => "unreviewed",
          "source_documents" => [ { "doc" => @doc_id } ]
        }
        data["version"] = "0.1.0"
        ordered(data)
      end

      def validate!(item_id, data)
        errors = Rulebook::Validator.validate(data)
        errors << "/item_id: model returned #{data['item_id'].inspect}, expected #{item_id.inspect}" if data["item_id"] != item_id
        return if errors.empty?

        raise Rejected.new(item_id, errors, save_reject(item_id, JSON.pretty_generate(data)))
      end

      def save_reject(item_id, text)
        @rejects_dir.mkpath
        path = @rejects_dir.join("#{item_id}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.json")
        path.write(text)
        path
      end

      # A required field whose schema type includes null (lookback_days) must survive compaction as an
      # explicit null: NOT_FOUND is a valid answer and the item is not valid without the key.
      def restore_required_nulls(data)
        schema = Rulebook::Schema.json
        schema.fetch("required", []).each do |key|
          next if data.key?(key)

          type = schema.dig("properties", key, "type")
          data[key] = nil if Array(type).include?("null")
        end
        data
      end

      # Drops nulls the model emitted for optional fields (the output schema makes them nullable).
      def compact(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), h| h[k] = compact(v) unless v.nil? }
        when Array then value.map { |v| compact(v) }
        else value
        end
      end

      def ordered(data)
        keys = Rulebook::Schema.json["properties"].keys
        data.slice(*keys).merge(data.except(*keys))
      end

      def relative(path)
        path.relative_path_from(Rails.root)
      rescue ArgumentError
        path
      end

      def log(message)
        @logger&.puts(message)
      end
    end
  end
end
