require "test_helper"

module Fogbell
  module Review
    class ApplyReviewTest < ActiveSupport::TestCase
      setup { @reviewer = create_user(role: "verifier", email: "reviewer@example.test") }

      def with_items_dir
        Dir.mktmpdir("rulebook-items") do |dir|
          FileUtils.cp(file_fixture("rulebook/valid_item.json"), File.join(dir, "X0100.json"))
          yield Pathname.new(dir)
        end
      end

      test "a correct criterion verdict sets verified_by_expert true and the item verified" do
        with_items_dir do |dir|
          changelog = Pipeline::Changelog.new(dir.join("changelog.md"))
          RuleReview.create!(item_id: "X0100", target: "rule:0", verdict: "correct", reviewer: @reviewer)
          RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer)

          results = ApplyReview.new(items_dir: dir, changelog: changelog).apply!
          assert_equal 1, results.size
          assert_equal "verified", results.first.status

          data = JSON.parse(dir.join("X0100.json").read)
          assert data.dig("supportive_documentation", "federal", 0, "verified_by_expert")
          assert_equal "verified", data.dig("provenance_summary", "expert_review_status")
          assert_equal "reviewer@example.test", data.dig("provenance_summary", "reviewed_by")
          assert_match(/reviewer=reviewer@example\.test status=verified/, changelog.path.read)

          assert_equal %w[applied applied], RuleReview.where(item_id: "X0100").pluck(:status)
        end
      end

      test "an incorrect rule verdict disputes the item without touching the rule JSON" do
        with_items_dir do |dir|
          RuleReview.create!(item_id: "X0100", target: "rule:1", verdict: "incorrect", notes: "admission-day checks do count", reviewer: @reviewer)

          results = ApplyReview.new(items_dir: dir, changelog: Pipeline::Changelog.new(dir.join("changelog.md"))).apply!
          assert_equal "disputed", results.first.status

          data = JSON.parse(dir.join("X0100.json").read)
          assert_equal "disputed", data.dig("provenance_summary", "expert_review_status")
          assert_not data["federal_coding_rules"][1].key?("verified_by_expert")
        end
      end

      test "only the most recently submitted review per target is applied; earlier ones are superseded" do
        with_items_dir do |dir|
          RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "incorrect", notes: "first pass", reviewer: @reviewer, submitted_at: 1.hour.ago)
          RuleReview.create!(item_id: "X0100", target: "criterion:0", verdict: "correct", reviewer: @reviewer, submitted_at: Time.current)

          results = ApplyReview.new(items_dir: dir, changelog: Pipeline::Changelog.new(dir.join("changelog.md"))).apply!
          assert_equal 1, results.first.applied
          assert_equal 1, results.first.superseded
          assert_equal "verified", results.first.status

          statuses = RuleReview.where(item_id: "X0100").order(:submitted_at).pluck(:status)
          assert_equal %w[rejected applied], statuses
        end
      end

      test "plan is empty when there is nothing pending" do
        assert_empty ApplyReview.new.plan
      end
    end
  end
end
