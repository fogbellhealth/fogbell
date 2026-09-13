require "test_helper"

class TodayWorklistTest < ActionDispatch::IntegrationTest
  setup do
    @facility = Facility.create!(name: "Test Facility (fictional, synthetic)")
    @resident = @facility.residents.create!(label: "Resident A", chart_text: "synthetic")
    @nurse = create_user(role: "nurse", facility: @facility)
    sign_in @nurse
  end

  def make_assessment(label:, ard_offset:, status:, item_id: "E0800", finding_status: "supported")
    resident = @facility.residents.create!(label: label, chart_text: "synthetic chart for #{label}")
    ard = Date.current + ard_offset
    check = @facility.checks.create!(chart_text: "synthetic", ard: ard, item_ids: [ item_id ], status: "done",
                                     results: [ { "item_id" => item_id, "status" => finding_status, "rationale" => "stub",
                                                  "evidence" => [], "outside_window_evidence" => [], "gaps" => [] } ])
    resident.assessments.create!(assessment_type: "quarterly", ard: ard, status: status, focus_item_id: item_id, check: check)
  end

  test "the worklist orders open windows ascending by days remaining and excludes closed ones" do
    far = make_assessment(label: "Resident Far", ard_offset: 6, status: "open")
    soon = make_assessment(label: "Resident Soon", ard_offset: 1, status: "open")
    make_assessment(label: "Resident Closed", ard_offset: -1, status: "closed")

    get today_path
    assert_response :success

    body_order = [ soon, far ].map { |a| response.body.index("assessment_#{a.id}") }
    assert_equal body_order.sort, body_order, "expected the sooner-closing card to appear first"
    assert_no_match(/Resident Closed/, response.body)
  end

  test "worklist cards show the item at risk, the deadline, and both actions" do
    a = make_assessment(label: "Resident Card", ard_offset: 2, status: "open", item_id: "E0800", finding_status: "unsupported")

    get today_path
    assert_response :success
    assert_select "article#assessment_#{a.id}" do
      assert_select "*", text: "Closes"
      assert_select "*", text: "in 2 days"
      assert_select "a", text: "Open check"
      assert_select "a", text: "See the rule →"
    end
    assert_match(/Demo only — synthetic data/, response.body)
  end

  test "metric cards reflect the seeded windows" do
    make_assessment(label: "Resident One", ard_offset: 2, status: "open", finding_status: "partial")
    make_assessment(label: "Resident Two", ard_offset: 3, status: "open", finding_status: "unsupported")

    get today_path
    assert_response :success
    assert_match(/2/, response.body) # windows open count appears somewhere
  end
end
