require "test_helper"

module Fogbell
  module EvidenceCheck
    class AuditProjectionTest < ActiveSupport::TestCase
      REVIEW = Rulebook::Item.from_hash(JSON.parse(<<~JSON))
        {"item_id":"CONV-XX-REVIEW","item_name":"review","section":"CONV","instrument":"MDS-3.0","lookback_days":null,"lookback_notes":"n/a",
         "coding_levels":[],
         "federal_coding_rules":[
           {"rule":"sample","source":{"doc":"state-rule","loc":"§16.2.3.3(3)","quote":"A record sample of twenty-four percent (24%) with a minimum of five (5) records shall be drawn from MDS assessments completed for residents who have MaineCare reimbursement."}},
           {"rule":"t1","source":{"doc":"state-rule","loc":"§16.2.3.4(1)","quote":"A two percent (2%) decrease in the Direct Care Rate will be imposed when the NF assessment review results in an error rate of thirty-four percent (34%) or greater, but is less than thirty-seven percent (37%)."}},
           {"rule":"t2","source":{"doc":"state-rule","loc":"§16.2.3.4(2)","quote":"A five percent (5%) decrease in the Direct Care Rate will be imposed when the NF assessment review results in an error rate of thirty-seven percent (37%) or greater, but is less than forty-one percent (41%)."}},
           {"rule":"t3","source":{"doc":"state-rule","loc":"§16.2.3.4(3)","quote":"A seven percent (7%) decrease in the Direct Care Rate will be imposed when NF assessment review results in an error rate of forty-one percent (41%) or greater, but is less than forty-five percent (45%)."}},
           {"rule":"t4","source":{"doc":"state-rule","loc":"§16.2.3.4(4)","quote":"A ten percent (10%) decrease in the Direct Care Rate will be imposed when the NF assessment review results in an error rate of forty-five percent (45%) or greater."}},
           {"rule":"corr","source":{"doc":"state-rule","loc":"§16.2.3.5","quote":"Failure to complete MDS corrections by the nursing facility staff within fourteen (14) days of a written request by staff of the Office of MaineCare Services may result in the imposition of the deficiency per diem."}}
         ],
         "supportive_documentation":{"federal":[],"state":{}},"state_deltas":[],"case_mix_relevance":{"level":"unknown","notes":"n/a"},"conflicts":[],"common_audit_citations":[],"not_found":[],
         "provenance_summary":{"extracted_at":"2026-09-06","model":"stub","expert_review_status":"unreviewed","source_documents":[{"doc":"state-rule"}]},"version":"0.1.0"}
      JSON

      def results(*statuses) = statuses.map { |s| { "status" => s } }
      def proj(*statuses) = AuditProjection.new(results(*statuses), review_item: REVIEW)

      test "reads the machinery from the cited quotes" do
        p = proj("supported")
        assert p.available?
        assert_equal [ 34, 37, 41, 45 ], p.tiers.map(&:error_rate_min)
        assert_equal [ 2, 5, 7, 10 ], p.tiers.map(&:reduction_pct)
        assert_equal "§16.2.3.4(1)", p.tiers.first.source["loc"]
        assert_equal({ pct: 24, min_records: 5 }, p.sample.value)
        assert_equal 14, p.correction_days.value
      end

      test "zero items: no rate, no tier" do
        p = proj
        assert_equal 0, p.checked
        assert_nil p.error_rate_pct
        assert_nil p.tier
      end

      test "all supported: 0% and the next tier is the 34% one" do
        p = proj(*[ "supported" ] * 5)
        assert_equal 0, p.error_rate_pct
        assert_nil p.tier
        assert_equal 34, p.next_tier.error_rate_min
      end

      test "exactly 34% lands on the 2% tier; just under does not" do
        p = AuditProjection.new(results(*[ "unsupported" ] * 34 + [ "supported" ] * 66), review_item: REVIEW)
        assert_equal 34, p.error_rate_pct
        assert_equal 2, p.tier.reduction_pct
        q = AuditProjection.new(results(*[ "unsupported" ] * 33 + [ "supported" ] * 67), review_item: REVIEW)
        assert_nil q.tier
      end

      test "partial counts half; not_applicable is excluded from the denominator" do
        p = proj("unsupported", "partial", "supported", "supported", "not_applicable")
        assert_equal 4, p.checked
        assert_in_delta 1.5, p.weighted_errors
        assert_equal 38, p.error_rate_pct
        assert_equal 5, p.tier.reduction_pct
      end

      test "45% and above is the 10% tier" do
        assert_equal 10, proj("unsupported", "unsupported", "supported", "supported").tier.reduction_pct
      end

      test "unavailable without a review item or without parseable quotes" do
        assert_not AuditProjection.new(results("unsupported"), review_item: nil).available?
        plain = Rulebook::Item.from_hash(JSON.parse(file_fixture("rulebook/valid_item.json").read))
        assert_not AuditProjection.new(results("unsupported"), review_item: plain).available?
      end
    end
  end
end
