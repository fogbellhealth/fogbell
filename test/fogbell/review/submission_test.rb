require "test_helper"

module Fogbell
  module Review
    class SubmissionTest < ActiveSupport::TestCase
      def with_items_dir
        Dir.mktmpdir("rulebook-items") do |dir|
          FileUtils.cp(file_fixture("rulebook/valid_item.json"), File.join(dir, "X0100.json"))
          yield Pathname.new(dir)
        end
      end

      test "a correct verdict on a criterion sets verified_by_expert true and the item verified" do
        with_items_dir do |dir|
          changelog = Pipeline::Changelog.new(dir.join("changelog.md"))
          outcome = Submission.new("X0100", reviewer: "J. Doucette, RN",
                                    rule_verdicts: { "0" => { "verdict" => "correct" }, "1" => { "verdict" => "correct" } },
                                    criterion_verdicts: { "0" => { "verdict" => "correct" } },
                                    items_dir: dir, changelog: changelog).apply!

          assert_equal "verified", outcome.status
          assert_empty outcome.disputes

          data = JSON.parse(dir.join("X0100.json").read)
          assert data.dig("supportive_documentation", "federal", 0, "verified_by_expert")
          assert_equal "verified", data.dig("provenance_summary", "expert_review_status")
          assert_equal "J. Doucette, RN", data.dig("provenance_summary", "reviewed_by")
          assert_equal Date.current.iso8601, data.dig("provenance_summary", "reviewed_at")
          assert_match(/review · X0100.*reviewer=J\. Doucette, RN status=verified/, changelog.path.read)
        end
      end

      test "a wrong verdict on a rule disputes the item and is logged, without touching rule JSON (no schema field to write)" do
        with_items_dir do |dir|
          changelog = Pipeline::Changelog.new(dir.join("changelog.md"))
          outcome = Submission.new("X0100", reviewer: "J. Doucette, RN",
                                    rule_verdicts: { "0" => { "verdict" => "correct" }, "1" => { "verdict" => "wrong", "note" => "admission-day checks do count" } },
                                    criterion_verdicts: { "0" => { "verdict" => "correct" } },
                                    items_dir: dir, changelog: changelog).apply!

          assert_equal "disputed", outcome.status
          assert_equal [ "rule 2: wrong — admission-day checks do count" ], outcome.disputes

          data = JSON.parse(dir.join("X0100.json").read)
          assert_equal "disputed", data.dig("provenance_summary", "expert_review_status")
          # federal_coding_rules has no verified_by_expert field in the schema; the rule text itself is untouched.
          assert_equal "A check performed before admission does not count.", data.dig("federal_coding_rules", 1, "rule")
          assert_not data["federal_coding_rules"][1].key?("verified_by_expert")
        end
      end

      test "a wrong verdict on a criterion writes verified_by_expert false and a reviewer note, and disputes the item" do
        with_items_dir do |dir|
          changelog = Pipeline::Changelog.new(dir.join("changelog.md"))
          outcome = Submission.new("X0100", reviewer: "J. Doucette, RN",
                                    rule_verdicts: {},
                                    criterion_verdicts: { "0" => { "verdict" => "different", "note" => "Maine auditors also accept a verbal handoff note" } },
                                    items_dir: dir, changelog: changelog).apply!

          assert_equal "disputed", outcome.status
          data = JSON.parse(dir.join("X0100.json").read)
          criterion = data.dig("supportive_documentation", "federal", 0)
          assert_equal false, criterion["verified_by_expert"]
          assert_match(/auditors apply it differently/, criterion["notes"])
          assert_match(/Maine auditors also accept a verbal handoff note/, criterion["notes"])
        end
      end

      test "an unknown item id raises" do
        with_items_dir do |dir|
          error = assert_raises(Error) do
            Submission.new("NOPE", reviewer: "x", rule_verdicts: {}, criterion_verdicts: {},
                            items_dir: dir, changelog: Pipeline::Changelog.new(dir.join("changelog.md"))).apply!
          end
          assert_match(/no such rulebook item/, error.message)
        end
      end
    end
  end
end
