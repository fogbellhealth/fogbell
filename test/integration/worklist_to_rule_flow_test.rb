require "test_helper"

# Walks the full path the product's shape is built around: Today (worklist) -> open a check for
# one card -> watch verdicts land -> click through to the rule behind the finding. An integration
# test rather than a browser-driven system test, matching this app's existing "system test"
# (test/integration/evidence_check_flow_test.rb) — no Capybara/selenium driver is set up here yet.
class WorklistToRuleFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    facility = Facility.create!(name: "Test Facility (fictional, synthetic)")
    resident = facility.residents.create!(label: "Resident Flow", chart_text: "SYNTHETIC — no rejection of care documented in this excerpt.")
    @ard = Date.current + 2
    seed_check = Check.create!(chart_text: resident.chart_text, ard: @ard, item_ids: [ "E0800" ], status: "done",
                                results: [ { "item_id" => "E0800", "status" => "unsupported", "rationale" => "stub" } ])
    @assessment = resident.assessments.create!(assessment_type: "quarterly", ard: @ard, status: "open",
                                                focus_item_id: "E0800", check: seed_check)

    payload = { "items" => [
      { "item_id" => "E0800", "status" => "unsupported", "suggested_coding" => "0 (not exhibited)",
        "rationale" => "No rejection-of-care documentation found.", "evidence" => [], "outside_window_evidence" => [],
        "gaps" => [ "no supporting note" ], "chart_today_action" => nil, "rules_applied" => [ 1 ] }
    ], "overall_note" => "Draft." }
    Fogbell::EvidenceCheck.llm_builder = -> { Fogbell::Pipeline::Llm::StubClient.new(text: JSON.generate(payload)) }
  end

  teardown { Fogbell::EvidenceCheck.llm_builder = nil }

  test "Today -> open a check -> see verdicts -> click through to the rule" do
    get root_path
    assert_response :success
    assert_select "article#assessment_#{@assessment.id} a", text: "Open check"

    get new_check_path(assessment_id: @assessment.id)
    assert_response :success
    assert_select "input[type=checkbox][value='E0800'][checked]"
    assert_select "textarea[name='check[chart_text]']", text: /rejection of care documented/

    perform_enqueued_jobs do
      post checks_path, params: { check: { chart_text: @assessment.resident.chart_text, ard: @ard.iso8601, item_ids: [ "E0800" ] } }
    end
    check = Check.last
    assert_redirected_to check_path(check)
    follow_redirect!
    assert_response :success
    assert_select "article#card_E0800 span", text: "UNSUPPORTED"

    assert_select "article#card_E0800 a[href=?]", rulebook_item_path("E0800")
    get rulebook_item_path("E0800")
    assert_response :success
    assert_select "a", text: "Run a check using this item"
  end
end
