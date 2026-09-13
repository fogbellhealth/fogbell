# frozen_string_literal: true

module Fogbell
  module Review
    # Materializes pending RuleReview rows into rulebook/items/*.json. The only path that writes
    # to the corpus from review markup — the web app only ever creates "pending" RuleReview rows.
    # See `rake rulebook:apply_review` (lib/tasks/rulebook.rake), which drives this and refuses to
    # run against a dirty rulebook/ tree so the resulting diff is always clean and reviewable.
    class ApplyReview
      Summary = Data.define(:item_id, :applied, :superseded, :status)

      def initialize(items_dir: Rulebook.items_dir, changelog: Pipeline::Changelog.new(Rulebook.root.join("changelog.md")))
        @items_dir = Pathname(items_dir)
        @changelog = changelog
      end

      def pending_reviews
        RuleReview.pending.order(:item_id, :submitted_at)
      end

      # Pending reviews grouped by item, with only the most recently submitted review per target
      # (rule:N / criterion:N) treated as authoritative; earlier duplicate-target submissions are
      # "superseded", not applied.
      def plan
        pending_reviews.group_by(&:item_id).transform_values do |reviews|
          winners = reviews.group_by(&:target).values.map { |rs| rs.max_by(&:submitted_at) }
          { winners: winners, superseded: reviews - winners }
        end
      end

      def apply!
        plan.map { |item_id, grouping| apply_item(item_id, grouping[:winners], grouping[:superseded]) }
      end

      private

      def apply_item(item_id, winners, superseded)
        path = @items_dir.join("#{item_id}.json")
        raise Rulebook::Error, "#{item_id}: no such rulebook item at #{path}" unless path.exist?

        data = JSON.parse(path.read)
        disputes = []

        winners.each do |review|
          if review.criterion_target?
            criterion = data.dig("supportive_documentation", "federal", review.target_index)
            next unless criterion

            if review.verdict == "correct"
              criterion["verified_by_expert"] = true
            else
              criterion["verified_by_expert"] = false
              criterion["notes"] = "Reviewer (#{review.reviewer.email}, #{review.submitted_at.to_date.iso8601}) marked #{describe(review.verdict)}: #{review.notes.presence || '(no note given)'}"
              disputes << "criterion #{review.target_index + 1}: #{describe(review.verdict)}"
            end
          elsif review.verdict != "correct"
            disputes << "rule #{review.target_index + 1}: #{describe(review.verdict)}#{" — #{review.notes}" if review.notes.present?}"
          end
        end

        status = disputes.any? ? "disputed" : "verified"
        reviewer_names = winners.map { |r| r.reviewer.email }.uniq.join(", ")
        data["provenance_summary"]["expert_review_status"] = status
        data["provenance_summary"]["reviewed_by"] = reviewer_names
        data["provenance_summary"]["reviewed_at"] = winners.map(&:submitted_at).max.to_date.iso8601

        path.write(JSON.pretty_generate(data) + "\n")
        @changelog.append(action: "review", item_id: item_id, doc: "human-review", model: "n/a",
                          note: "reviewer=#{reviewer_names} status=#{status}#{"; #{disputes.join('; ')}" if disputes.any?}")

        now = Time.current
        winners.each { |r| r.update!(status: "applied", applied_at: now) }
        superseded.each { |r| r.update!(status: "rejected", applied_at: now, notes: "#{r.notes} (superseded by a later submission for the same target)".strip) }

        Summary.new(item_id: item_id, applied: winners.size, superseded: superseded.size, status: status)
      end

      def describe(verdict) = { "incorrect" => "incorrect", "applied_differently" => "auditors apply it differently" }.fetch(verdict, verdict)
    end
  end
end
