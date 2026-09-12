require "test_helper"

class AssessmentTest < ActiveSupport::TestCase
  setup do
    @facility = Facility.create!(name: "Test Facility (fictional, synthetic)")
    @resident = @facility.residents.create!(label: "Resident TEST", chart_text: "synthetic chart text")
  end

  def make(ard_offset:, status:)
    @resident.assessments.create!(assessment_type: "quarterly", ard: Date.current + ard_offset, status: status, focus_item_id: "E0800")
  end

  test "open_windows excludes closed assessments" do
    open_one = make(ard_offset: 3, status: "open")
    make(ard_offset: -2, status: "closed")

    assert_equal [ open_one ], Assessment.open_windows.to_a
  end

  test "open_windows orders ascending by days remaining (soonest first)" do
    far = make(ard_offset: 6, status: "open")
    soon = make(ard_offset: 1, status: "open")
    mid = make(ard_offset: 3, status: "open")

    assert_equal [ soon, mid, far ], Assessment.open_windows.to_a
  end

  test "days_remaining is relative to today, not a stored value" do
    a = make(ard_offset: 4, status: "open")
    assert_equal 4, a.days_remaining
  end

  test "finding returns nil when there is no check, and the matching result once the check is done" do
    a = make(ard_offset: 2, status: "open")
    assert_nil a.finding

    check = Check.create!(chart_text: "x", ard: a.ard, item_ids: [ "E0800" ], status: "done",
                           results: [ { "item_id" => "E0800", "status" => "supported" } ])
    a.update!(check: check)

    assert_equal "supported", a.finding["status"]
  end

  test "finding matches a lettered sub-item answer for a requested parent item" do
    a = @resident.assessments.create!(assessment_type: "quarterly", ard: Date.current + 2, status: "open", focus_item_id: "E0200")
    check = Check.create!(chart_text: "x", ard: a.ard, item_ids: [ "E0200" ], status: "done",
                           results: [ { "item_id" => "E0200A", "status" => "supported" }, { "item_id" => "E0200B", "status" => "partial" } ])
    a.update!(check: check)

    assert_equal "supported", a.finding["status"]
  end
end
