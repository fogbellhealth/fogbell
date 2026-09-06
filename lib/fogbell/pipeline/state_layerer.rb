# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Layers one state's document onto an existing (federal) rulebook item:
    #   item + state document -> prompt -> LLM -> fragment {state criteria, deltas, conflicts}
    #   -> citation check (every finding cites the state doc) -> merge -> validate -> write -> changelog.
    # Nothing is written unless the merged item is schema-valid; rejects go to rejects_dir.
    class StateLayerer
      Result = Data.define(:item_id, :path, :data, :added)

      MODES = %w[auto text pdf].freeze
      TEMPLATE = "lib/prompts/layer_state.md.erb"

      def initialize(doc:, doc_id:, state:, llm:, items_dir:, out_dir:, mode: "auto", force: false,
                     template: PromptTemplate.new(Rails.root.join(TEMPLATE)), changelog: nil,
                     rejects_dir: Rails.root.join("tmp/rulebook_rejects"), shell: Shell.new, logger: nil)
        raise Error, "MODE must be one of #{MODES.join(', ')}" unless MODES.include?(mode)
        raise Error, "STATE must be a two-letter code, got #{state.inspect}" unless state.to_s.match?(/\A[A-Z]{2}\z/)

        @source = TextSource.new(doc, shell: shell)
        @doc_id = doc_id
        @state = state
        @llm = llm
        @items_dir = Pathname(items_dir)
        @out_dir = Pathname(out_dir)
        @mode = mode
        @force = force
        @template = template
        @changelog = changelog || Changelog.new(@out_dir.parent.join("changelog.md"))
        @rejects_dir = Pathname(rejects_dir)
        @logger = logger
      end

      def prompt_for(item_id)
        prepare(item_id, load_item(item_id)).first
      end

      def run(item_id)
        item = load_item(item_id)
        target = @out_dir.join("#{item_id}.json")
        raise AlreadyExists, "#{target} exists; pass FORCE=1 to overwrite" if target.exist? && !@force

        prompt, pdf, doc_text = prepare(item_id, item)
        log "#{item_id}: layer #{@state} from #{@doc_id} (#{pdf ? 'PDF attached' : "text, #{@source.pages.size} parts"}), model #{@llm.model}"

        response = @llm.complete(system: prompt.system, user: prompt.user, output_schema: OutputSchema.build_for_layer,
                                 pdf: pdf, pdf_title: @doc_id, document_text: doc_text)
        log "#{item_id}: usage #{response.usage.inspect}"
        fragment = compact(parse(item_id, response.text))
        check_citations!(item_id, fragment)
        merged, added = merge(item, fragment)
        validate!(item_id, merged)

        @out_dir.mkpath
        target.write(JSON.pretty_generate(merged) + "\n")
        @changelog.append(action: "layer_state", item_id: item_id, doc: @doc_id, model: response.model,
                          note: "state=#{@state} #{added.map { |k, v| "#{k}=#{v}" }.join(' ')}; " \
                                "not found: #{Array(fragment['not_found']).join(', ').presence || 'nothing reported'}; written to #{relative(target)}")
        log "#{item_id}: wrote #{relative(target)} (#{added.map { |k, v| "#{k} +#{v}" }.join(', ')})"
        Result.new(item_id: item_id, path: target, data: merged, added: added)
      end

      private

      def load_item(item_id)
        path = @items_dir.join("#{item_id}.json")
        raise Error, "no promoted item #{item_id} in #{@items_dir}" unless path.file?

        JSON.parse(path.read)
      end

      def prepare(item_id, item)
        locals = { item_id: item_id, item_name: item["item_name"], instrument: item["instrument"], state: @state,
                   doc_id: @doc_id, federal_summary_json: JSON.pretty_generate(federal_summary(item)),
                   output_schema_json: JSON.pretty_generate(OutputSchema.build_for_layer) }
        if use_pdf?
          [ @template.render(**locals, attachment: true), @source.pdf_bytes, nil ]
        else
          [ @template.render(**locals, attachment: false), nil, Chunker.render(@source.pages) ]
        end
      end

      # The part of the federal item the model needs to compare against: rules, levels, window, criteria.
      def federal_summary(item)
        {
          "lookback_days" => item["lookback_days"], "lookback_source" => item["lookback_source"], "lookback_notes" => item["lookback_notes"],
          "coding_levels" => item["coding_levels"].map { |l| l.slice("code", "label") },
          "federal_coding_rules" => item["federal_coding_rules"],
          "federal_supportive_documentation" => item.dig("supportive_documentation", "federal"),
          "existing_conflicts" => item["conflicts"].map { |c| c["topic"] }
        }
      end

      def use_pdf?
        case @mode
        when "pdf" then true
        when "text" then false
        else @source.kind == :pdf && @source.looks_scanned?
        end
      end

      def parse(item_id, text)
        JSON.parse(text.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, ""))
      rescue JSON::ParserError => e
        raise Rejected.new(item_id, [ "model output is not valid JSON: #{e.message}" ], save_reject(item_id, text))
      end

      # Every finding must cite the state document; the only exception is the federal side of a conflict.
      def check_citations!(item_id, fragment)
        bad = []
        Array(fragment["state_supportive_documentation"]).each_with_index { |c, i| bad << "state criterion #{i + 1} cites #{c.dig('source', 'doc').inspect}" unless c.dig("source", "doc") == @doc_id }
        Array(fragment["state_deltas"]).each_with_index { |d, i| bad << "state delta #{i + 1} cites #{d.dig('source', 'doc').inspect}" unless d.dig("source", "doc") == @doc_id }
        Array(fragment["conflicts"]).each_with_index do |c, i|
          docs = Array(c["positions"]).map { |p| p.dig("source", "doc") }
          bad << "conflict #{i + 1} has no position citing #{@doc_id}" unless docs.include?(@doc_id)
        end
        cm = fragment["case_mix_relevance"]
        bad << "case_mix_relevance cites #{cm.dig('source', 'doc').inspect}" if cm && cm["source"] && cm.dig("source", "doc") != @doc_id
        return if bad.empty?

        raise Rejected.new(item_id, bad, save_reject(item_id, JSON.pretty_generate(fragment)))
      end

      # Idempotent for (state, doc): re-running replaces this layer's earlier findings instead of duplicating them.
      def merge(item, fragment)
        data = JSON.parse(JSON.generate(item))
        criteria = Array(fragment["state_supportive_documentation"]).each { |c| c["verified_by_expert"] = false }
        deltas = Array(fragment["state_deltas"]).each { |d| d["state"] = @state }
        conflicts = Array(fragment["conflicts"])

        data["supportive_documentation"]["state"] ||= {}
        data["supportive_documentation"]["state"][@state] = criteria
        data["state_deltas"] = Array(data["state_deltas"]).reject { |d| from_this_layer?(d) } + deltas
        data["conflicts"] = Array(data["conflicts"]).reject { |c| c["positions"].any? { |p| from_this_layer?(p) } } + conflicts

        if (cm = fragment["case_mix_relevance"])
          if data.dig("case_mix_relevance", "level").to_s == "unknown" || data["case_mix_relevance"].nil?
            data["case_mix_relevance"] = cm
          else
            data["case_mix_relevance"]["notes"] = [ data["case_mix_relevance"]["notes"], "#{@state} (#{cm.dig('source', 'loc')}): #{cm['notes']}" ].compact.join(" ")
          end
        end

        docs = data["provenance_summary"]["source_documents"] ||= []
        docs << { "doc" => @doc_id } unless docs.any? { |d| d["doc"] == @doc_id }

        [ data, { "criteria" => criteria.size, "deltas" => deltas.size, "conflicts" => conflicts.size, "case_mix" => cm ? 1 : 0 } ]
      end

      def from_this_layer?(entry)
        entry.dig("source", "doc") == @doc_id
      end

      def validate!(item_id, data)
        errors = Rulebook::Validator.validate(data)
        return if errors.empty?

        raise Rejected.new(item_id, errors, save_reject(item_id, JSON.pretty_generate(data)))
      end

      def save_reject(item_id, text)
        @rejects_dir.mkpath
        path = @rejects_dir.join("#{item_id}-layer-#{@state}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.json")
        path.write(text)
        path
      end

      def compact(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), h| h[k] = compact(v) unless v.nil? }
        when Array then value.map { |v| compact(v) }
        else value
        end
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
