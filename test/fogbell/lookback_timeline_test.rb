require "test_helper"

module Fogbell
  class LookbackTimelineTest < ActiveSupport::TestCase
    ARD = Date.new(2026, 9, 10)

    test "not computable when lookback_days is nil" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: nil)
      assert_not t.computable?
      assert_empty t.days
      assert_equal 0, t.column_count
      assert_match(/not stated/, t.summary)
    end

    test "renders 2 lead days plus the window (7-day window -> 9 columns)" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7)
      assert t.computable?
      assert_equal 9, t.column_count
      assert_equal 9, t.days.size
      assert_equal ARD - 8, t.days.first.date # 2 lead days before the 7-day window
      assert_equal ARD, t.days.last.date
      assert t.days.last.is_ard
      assert t.days.last.in_window
      assert_not t.days.first.in_window
    end

    test "in-window evidence is bucketed onto the correct day" do
      evidence = [ { "date" => "09/08/2026", "author" => "J. Okafor, LPN", "quote" => "note" } ]
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, evidence: evidence)
      day = t.days.find { |d| d.date == Date.new(2026, 9, 8) }
      assert day.in_window
      assert_equal 1, day.entries.size
      assert_match(/1 supporting note/, t.summary)
    end

    test "outside-window evidence within the 2-day lead-in is plotted as stranded" do
      outside = [ { "date" => "09/03/2026", "author" => "R. Bilodeau, LCSW", "quote" => "too early" } ]
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, outside_window_evidence: outside)
      day = t.days.find { |d| d.date == Date.new(2026, 9, 3) }
      assert_not day.in_window
      assert_equal 1, day.outside_entries.size
      assert_equal 0, t.unplotted_count
      assert_match(/1 note outside the window/, t.summary)
    end

    test "outside-window evidence earlier than the lead-in is real but not plotted" do
      outside = [ { "date" => "08/20/2026", "author" => "R. Bilodeau, LCSW", "quote" => "way too early" } ]
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, outside_window_evidence: outside)
      assert t.days.all? { |d| d.outside_entries.empty? }
      assert_equal 1, t.stranded_count
      assert_equal 1, t.unplotted_count
    end

    test "empty evidence renders a full day strip with every cell empty (looks sparse)" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7)
      assert_equal 9, t.days.size
      assert t.days.all? { |d| d.entries.empty? && d.outside_entries.empty? }
      assert_equal 0, t.evidence_count
      assert t.sparse?
      assert_match(/No supporting evidence/, t.summary)
    end

    test "is_today is only set when today falls within the rendered range" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, today: ARD - 3)
      assert t.days.any?(&:is_today)

      far_future = LookbackTimeline.new(ard: ARD, lookback_days: 7, today: ARD + 30)
      assert far_future.days.none?(&:is_today)
    end
  end
end
