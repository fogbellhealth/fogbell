require "test_helper"

# The two role domains are a security boundary, not cosmetics — see CLAUDE.md's "Role model" note.
# These tests assert the denials directly: a rulebook-domain session must never reach facility
# data, and a facility-domain session must never reach the review queue, regardless of what the
# nav shows.
class DomainPolicyTest < ActionDispatch::IntegrationTest
  setup do
    @facility_a = Facility.create!(name: "Facility A (fictional, synthetic)")
    @facility_b = Facility.create!(name: "Facility B (fictional, synthetic)")
    @nurse_a = create_user(role: "nurse", facility: @facility_a)
    @nurse_b = create_user(role: "nurse", facility: @facility_b)
    @verifier = create_user(role: "verifier")

    @resident_a = @facility_a.residents.create!(label: "Resident A1", chart_text: "synthetic")
    @assessment_a = @resident_a.assessments.create!(assessment_type: "quarterly", ard: Date.current + 2, status: "open", focus_item_id: "E0800")
    @check_a = @facility_a.checks.create!(chart_text: "synthetic", ard: Date.current + 2, item_ids: [ "E0800" ])

    @resident_b = @facility_b.residents.create!(label: "Resident B1", chart_text: "synthetic")
  end

  # --- Rulebook-domain user hitting facility routes: denied, at every one named in the brief ---

  test "a verifier hitting a resident URL is denied" do
    sign_in @verifier
    get resident_path(@resident_a)
    assert_response :not_found
  end

  test "a verifier hitting a check URL is denied" do
    sign_in @verifier
    get check_path(@check_a)
    assert_response :not_found
  end

  test "a verifier hitting an assessment URL is denied" do
    sign_in @verifier
    get assessment_path(@assessment_a)
    assert_response :not_found
  end

  test "a verifier hitting Today (the worklist root) is denied" do
    sign_in @verifier
    get today_path
    assert_response :not_found
  end

  test "a verifier hitting the check form or creating a check is denied" do
    sign_in @verifier
    get new_check_path
    assert_response :not_found

    post checks_path, params: { check: { chart_text: "x", ard: Date.current.iso8601, item_ids: [ "E0800" ] } }
    assert_response :not_found
    assert_equal 0, Check.where(chart_text: "x").count
  end

  test "signing in as a verifier redirects to the review queue, not the worklist" do
    sign_in @verifier
    get root_path
    assert_redirected_to review_path
  end

  # --- Facility-domain user hitting the review queue: denied ---

  test "a nurse hitting the review queue is denied" do
    sign_in @nurse_a
    get review_path
    assert_response :not_found
  end

  test "a nurse hitting a specific item's review form is denied" do
    item_id = Fogbell::Rulebook.instance.ids.first
    sign_in @nurse_a
    get review_item_path(item_id)
    assert_response :not_found
  end

  test "a nurse submitting review markup is denied and nothing is created" do
    item_id = Fogbell::Rulebook.instance.ids.first
    sign_in @nurse_a
    post review_item_path(item_id), params: { rules: { "0" => { verdict: "correct" } } }
    assert_response :not_found
    assert_equal 0, RuleReview.count
  end

  test "signing in as a nurse redirects to Today, not the review queue" do
    sign_in @nurse_a
    get root_path
    assert_redirected_to today_path
  end

  # --- Both domains can read the shared surfaces ---

  test "both a nurse and a verifier can read the rulebook and the changes feed" do
    [ @nurse_a, @verifier ].each do |user|
      sign_in user
      get rulebook_path
      assert_response :success
      get changes_path
      assert_response :success
      sign_out user
    end
  end

  # --- Facility scoping: a nurse at facility A cannot reach facility B's data ---

  test "a nurse at facility A cannot reach facility B's resident" do
    sign_in @nurse_a
    get resident_path(@resident_b)
    assert_response :not_found
  end

  test "a nurse at facility A cannot open a check for facility B's assessment" do
    assessment_b = @resident_b.assessments.create!(assessment_type: "quarterly", ard: Date.current + 3, status: "open", focus_item_id: "E0900")
    sign_in @nurse_a
    get new_check_path(assessment_id: assessment_b.id)
    assert_response :success # falls back to the ad-hoc/default chart — it never finds facility B's assessment
    assert_no_match(/Resident B1/, response.body)
  end

  test "a nurse at facility A cannot view facility B's check by id" do
    check_b = @facility_b.checks.create!(chart_text: "synthetic B", ard: Date.current + 2, item_ids: [ "E0900" ])
    sign_in @nurse_a
    get check_path(check_b)
    assert_response :not_found
  end

  test "Today only lists facility A's own assessments, never facility B's" do
    @resident_b.assessments.create!(assessment_type: "quarterly", ard: Date.current + 1, status: "open", focus_item_id: "E0900")
    sign_in @nurse_a
    get today_path
    assert_response :success
    assert_match(/Resident A1/, response.body)
    assert_no_match(/Resident B1/, response.body)
  end

  # --- The dev-both-domains convenience account really does span both ---

  test "the dev_both_domains account can reach both Today and the review queue" do
    both = create_user(role: "nurse", facility: @facility_a, dev_both_domains: true)
    sign_in both
    get today_path
    assert_response :success
    get review_path
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end
end
