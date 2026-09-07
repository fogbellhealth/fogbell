# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # One check: rulebook items + chart + ARD -> one model call -> validated per-item results,
    # with the window rule enforced in code (out-of-window evidence is moved aside and never
    # counts, whatever the model said). Logs every request/response pair. Reports progress
    # through +on_item+ so the caller can stream cards as they are finalized.
    class Runner
      MAX_ATTEMPTS = 2
      TEMPLATE = "lib/prompts/evidence_check.md.erb"

      Result = Data.define(:items, :overall_note, :rule_set, :usage, :attempts)

      def initialize(check, llm: EvidenceCheck.llm, rulebook: Rulebook.instance, manifest: Review::Manifest.default,
                     template: Pipeline::PromptTemplate.new(Rails.root.join(TEMPLATE)), log_dir: Rails.root.join("log/evidence_checks"))
        @check = check
        @llm = llm
        @rulebook = rulebook
        @manifest = manifest
        @template = template
        @log_dir = Pathname(log_dir)
      end

      def items
        @items ||= @check.item_ids.map { |id| @rulebook.fetch(id) }
      end

      def conventions
        @conventions ||= @rulebook.select { |i| i.section == "CONV" && i.instrument == instrument }
      end

      def instrument = items.first&.instrument || "MDS-3.0"

      def rule_set
        @rule_set ||= RuleSet.new(items, conventions, manifest: @manifest)
      end

      def prompt
        @template.render(
          ard: @check.ard.strftime("%B %-d, %Y (%Y-%m-%d)"), instrument: instrument, chart_text: @check.chart_text,
          output_schema_json: JSON.pretty_generate(ResponseSchema.build),
          conventions: rule_set.conventions.map { |r| { n: r.n, text: r.text } },
          items: items.map do |it|
            { item_id: it.item_id, item_name: it.item_name, window_text: Window.new(@check.ard, it.lookback_days).text,
              lookback_notes: it.lookback_notes, coding_levels: it.coding_levels,
              rules: rule_set.for_item(it.item_id).map { |r| { n: r.n, text: r.text } } }
          end
        )
      end

      def run
        p = prompt
        errors = nil
        MAX_ATTEMPTS.times do |attempt|
          response = @llm.complete(system: p.system, user: p.user, output_schema: ResponseSchema.build)
          data = parse(response.text)
          errors = data ? ResponseSchema.validate(data) : [ "not valid JSON" ]
          errors += check_item_ids(data) if errors.empty?
          log(attempt + 1, p, response, errors)
          next unless errors.empty?

          finalized = data["items"].map { |r| enforce_window(r) }
          finalized.each { |r| yield r if block_given? }
          return Result.new(items: finalized, overall_note: data["overall_note"], rule_set: rule_set, usage: response.usage, attempts: attempt + 1)
        end
        raise InvalidResponse, "the model returned an unusable answer #{MAX_ATTEMPTS} times (#{errors.first(3).join('; ')}). Nothing was checked."
      end

      private

      def parse(text)
        JSON.parse(text.to_s.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, ""))
      rescue JSON::ParserError
        nil
      end

      def check_item_ids(data)
        got = data["items"].map { |r| r["item_id"] }
        missing = @check.item_ids - got
        extra = got - @check.item_ids
        [].tap do |e|
          e << "missing items: #{missing.join(', ')}" if missing.any?
          e << "unrequested items: #{extra.join(', ')}" if extra.any?
        end
      end

      # The window rule, enforced in code: evidence dated outside the item's window is moved to
      # outside_window_evidence, and a status that then has no in-window evidence left is downgraded.
      def enforce_window(result)
        item = @rulebook.fetch(result["item_id"])
        window = Window.new(@check.ard, item.lookback_days)
        inside, outside = result["evidence"].partition { |e| window.includes?(e["date"]) != false }
        r = result.merge("evidence" => inside, "outside_window_evidence" => result["outside_window_evidence"] + outside,
                         "window" => { "days" => item.lookback_days, "first_day" => window.first_day&.iso8601, "last_day" => window.last_day.iso8601 },
                         "downgraded" => false)
        if outside.any? && inside.empty? && %w[supported partial].include?(r["status"])
          r["status"] = "unsupported"
          r["downgraded"] = true
          r["gaps"] = r["gaps"] + [ "The only documentation offered is dated outside the #{item.lookback_days}-day window and cannot be counted." ]
        end
        r
      end

      def log(attempt, p, response, errors)
        @log_dir.mkpath
        path = @log_dir.join("check-#{@check.id}-attempt#{attempt}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.json")
        path.write(JSON.pretty_generate(
          "check_id" => @check.id, "attempt" => attempt, "model" => response.model, "usage" => response.usage.to_h,
          "validation_errors" => errors, "system" => p.system, "user" => p.user, "response" => response.text
        ))
      end
    end
  end
end
