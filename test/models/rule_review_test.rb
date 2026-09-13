require "test_helper"

class RuleReviewTest < ActiveSupport::TestCase
  setup { @verifier = create_user(role: "verifier") }

  test "defaults to pending status and submitted_at now" do
    r = RuleReview.create!(item_id: "X0100", target: "rule:0", verdict: "correct", reviewer: @verifier)
    assert_equal "pending", r.status
    assert_in_delta Time.current, r.submitted_at, 2.seconds
  end

  test "target must be rule:N or criterion:N" do
    r = RuleReview.new(item_id: "X0100", target: "bogus", verdict: "correct", reviewer: @verifier)
    assert_not r.valid?
  end

  test "target_kind and target_index parse the target string" do
    r = RuleReview.new(item_id: "X0100", target: "criterion:3", verdict: "correct", reviewer: @verifier)
    assert_equal "criterion", r.target_kind
    assert_equal 3, r.target_index
    assert r.criterion_target?
    assert_not r.rule_target?
  end
end
