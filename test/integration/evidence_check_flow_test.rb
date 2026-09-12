require "test_helper"

class EvidenceCheckFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ids = Fogbell::Rulebook.instance.ids
    @items = %w[D0150 E0200].select { |i| ids.include?(i) }
    skip "promoted rulebook items D0150/E0200 not present" if @items.size < 2
    payload = { "items" => @items.map { |id|
      { "item_id" => id, "status" => id == "E0200" ? "unsupported" : "supported", "suggested_coding" => "as charted", "rationale" => "Stubbed.",
        "evidence" => [ { "date" => "09/02/2026", "author" => "J. Okafor, LPN", "quote" => "stub quote" } ], "outside_window_evidence" => [], "gaps" => [ "stub gap" ],
        "chart_today_action" => nil, "rules_applied" => [ 1 ] } }, "overall_note" => "Draft." }
    Fogbell::EvidenceCheck.llm_builder = -> { Fogbell::Pipeline::Llm::StubClient.new(text: JSON.generate(payload)) }
  end

  teardown { Fogbell::EvidenceCheck.llm_builder = nil }

  test "form loads with the synthetic chart, the demo notice, and promoted items grouped by section" do
    get new_check_path
    assert_response :success
    assert_select "textarea[name='check[chart_text]']", text: /SYNTHETIC DEMONSTRATION RECORD/
    assert_select "input[type=date][name='check[ard]'][value='2026-09-03']"
    assert_select "input[type=checkbox][value='D0150'][checked]"
    assert_select "input[type=checkbox][value^='CONV-']", count: 0
    assert_match(/Demo only — synthetic data only/, response.body)
  end

  test "submitting runs the job and the result page shows cards with status, evidence and the why disclosure" do
    perform_enqueued_jobs do
      post checks_path, params: { check: { chart_text: Fogbell::EvidenceCheck::SyntheticChart.text, ard: "2026-09-03", item_ids: @items } }
    end
    check = Check.last
    assert_redirected_to check_path(check)
    assert_equal "done", check.reload.status
    follow_redirect!
    assert_response :success
    assert_select "article#card_D0150"
    assert_select "article#card_E0200 span", text: "UNSUPPORTED"
    assert_select "details summary", text: /Why\?/
    assert_match(/rai-manual-v1.20.1|RAI Manual/, response.body)
    assert_match(/Mock audit projection/, response.body)
  end

  test "with DEMO_PASSWORD set the app requires HTTP basic auth, and the health check does not" do
    ENV["DEMO_PASSWORD"] = "bell"
    get root_path
    assert_response :unauthorized
    get root_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("anyone", "bell") }
    assert_response :success
    get "/up"
    assert_response :success
  ensure
    ENV.delete("DEMO_PASSWORD")
  end

  test "an invalid selection re-renders the form with the error" do
    post checks_path, params: { check: { chart_text: "x", ard: "2026-09-03", item_ids: [] } }
    assert_response :unprocessable_entity
    assert_match(/must include at least one item/, response.body)
  end
end
