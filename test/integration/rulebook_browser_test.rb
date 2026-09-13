require "test_helper"

class RulebookBrowserTest < ActionDispatch::IntegrationTest
  setup { sign_in create_user(role: "verifier") }

  test "index shows headline counts and items grouped by instrument then section" do
    get rulebook_path
    assert_response :success
    assert_match(/promoted items/i, response.body)
    assert_select "h2", text: /MDS 3.0/
  end

  test "index filters by jurisdiction and by review status" do
    get rulebook_path(jurisdiction: "Maine")
    assert_response :success
    assert_select "a[href^='/rulebook/CONV-ME']", minimum: 1
    assert_select "a[href^='/rulebook/D0150']", count: 0

    get rulebook_path(status: "unreviewed")
    assert_response :success
    assert_select "a[href^='/rulebook/D0150']", minimum: 1
  end

  test "item page renders rules, sources, and links back to the checker" do
    skip "D0150 not promoted" unless Fogbell::Rulebook.instance.find("D0150")
    get rulebook_item_path("D0150")
    assert_response :success
    assert_select "h1", text: /./
    assert_select "a", text: "Run a check using this item"
    assert_match(/Sources/, response.body)
  end

  test "a Maine convention item shows its state layer badge and no run-a-check link" do
    skip "CONV-ME-MDS-REVIEW not promoted" unless Fogbell::Rulebook.instance.find("CONV-ME-MDS-REVIEW")
    get rulebook_item_path("CONV-ME-MDS-REVIEW")
    assert_response :success
    assert_match(/provisional pending expert review/, response.body)
    assert_select "a", text: "Run a check using this item", count: 0
  end

  test "unknown item id 404s" do
    get rulebook_item_path("NOPE-0000")
    assert_response :not_found
  end

  test "jurisdictions page renders the item-level absence finding and the program comparison" do
    get rulebook_jurisdictions_path
    assert_response :success
    assert_match(/honest absence|Maine-specific documentation delta/, response.body)
    assert_match(/Maine/, response.body)
  end
end
