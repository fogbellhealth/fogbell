require "test_helper"

# The actual HTTP path for submitting review markup — separate from apply_review_test.rb (which
# exercises Fogbell::Review::ApplyReview directly) and domain_policy_test.rb (which only asserts
# the denial for a nurse). This is the positive path: a verifier really can submit markup, and it
# lands as a pending RuleReview, never touching rulebook/items/*.json.
class ReviewSubmissionTest < ActionDispatch::IntegrationTest
  setup do
    @verifier = create_user(role: "verifier")
    sign_in @verifier
    @item_id = Fogbell::Rulebook.instance.detect { |i| i.federal_coding_rules.any? && i.supportive_documentation.fetch("federal", []).any? }&.item_id
    skip "no promoted item with both rules and criteria to test against" unless @item_id
  end

  test "submitting markup creates pending RuleReview rows, verdict values map correctly, and rulebook/ is untouched" do
    path_before = Fogbell::Rulebook.items_dir.join("#{@item_id}.json")
    contents_before = path_before.read

    post review_item_path(@item_id), params: {
      rules: { "0" => { verdict: "correct" } },
      criteria: { "0" => { verdict: "wrong", note: "the manual actually says something else" } }
    }
    assert_redirected_to review_path
    follow_redirect! # -> /review, which itself redirects to the first queued item
    follow_redirect!
    assert_match(/Submitted 2 markups/, response.body)

    reviews = RuleReview.for_item(@item_id)
    assert_equal 2, reviews.count
    assert_equal "correct", reviews.find_by(target: "rule:0").verdict
    assert_equal "incorrect", reviews.find_by(target: "criterion:0").verdict
    assert reviews.all? { |r| r.status == "pending" }
    assert reviews.all? { |r| r.reviewer_id == @verifier.id }

    assert_equal contents_before, path_before.read, "the web app must never write to rulebook/"
  end

  test "an item with pending review shows the pending badge on the queue" do
    RuleReview.create!(item_id: @item_id, target: "rule:0", verdict: "correct", reviewer: @verifier)

    get review_path(status: "pending")
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match(/#{Regexp.escape(@item_id)}/, response.body)
  end
end
