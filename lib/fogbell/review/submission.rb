# frozen_string_literal: true

module Fogbell
  module Review
    # Applies one reviewer's markup to a rulebook item's on-disk JSON: per-criterion
    # verified_by_expert + notes (schema fields that already exist), plus the item-level
    # provenance_summary (expert_review_status/reviewed_by/reviewed_at). Per-rule verdicts have
    # no schema field to write into (federal_coding_rules carries no verified_by_expert) — those
    # go into the changelog line only, not the item JSON. Appends one changelog line; the caller
    # is responsible for calling Rulebook.reset! so the change is visible without a restart.
    class Submission
      VERDICTS = %w[correct wrong different].freeze

      Outcome = Data.define(:item_id, :status, :disputes)

      def initialize(item_id, reviewer:, rule_verdicts:, criterion_verdicts:, items_dir: Rulebook.items_dir,
                     changelog: Pipeline::Changelog.new(Rulebook.root.join("changelog.md")))
        @item_id = item_id
        @reviewer = reviewer.presence || "anonymous reviewer"
        @rule_verdicts = rule_verdicts # { "0" => { "verdict" => "correct"|"wrong"|"different", "note" => "..." }, ... }
        @criterion_verdicts = criterion_verdicts
        @path = Pathname(items_dir).join("#{item_id}.json")
        @changelog = changelog
      end

      def apply!
        raise Error, "#{@item_id}: no such rulebook item" unless @path.exist?

        data = JSON.parse(@path.read)
        disputes = []

        criteria = data.dig("supportive_documentation", "federal") || []
        @criterion_verdicts.each do |idx, v|
          c = criteria[idx.to_i]
          next unless c

          if v["verdict"] == "correct"
            c["verified_by_expert"] = true
          else
            c["verified_by_expert"] = false
            c["notes"] = "Reviewer (#{@reviewer}, #{Date.current.iso8601}) marked #{describe(v['verdict'])}: #{v['note'].presence || '(no note given)'}"
            disputes << "criterion #{idx.to_i + 1}: #{describe(v['verdict'])}"
          end
        end

        @rule_verdicts.each do |idx, v|
          next if v["verdict"] == "correct"

          disputes << "rule #{idx.to_i + 1}: #{describe(v['verdict'])}#{" — #{v['note']}" if v['note'].present?}"
        end

        status = disputes.any? ? "disputed" : "verified"
        data["provenance_summary"]["expert_review_status"] = status
        data["provenance_summary"]["reviewed_by"] = @reviewer
        data["provenance_summary"]["reviewed_at"] = Date.current.iso8601

        @path.write(JSON.pretty_generate(data) + "\n")
        @changelog.append(action: "review", item_id: @item_id, doc: "human-review", model: "n/a",
                          note: "reviewer=#{@reviewer} status=#{status}#{"; #{disputes.join('; ')}" if disputes.any?}")
        Outcome.new(item_id: @item_id, status: status, disputes: disputes)
      end

      private

      def describe(verdict)
        { "wrong" => "wrong", "different" => "auditors apply it differently" }.fetch(verdict, verdict)
      end
    end
  end
end
