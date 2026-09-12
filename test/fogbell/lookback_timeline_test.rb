require "test_helper"

module Fogbell
  class LookbackTimelineTest < ActiveSupport::TestCase
    ARD = Date.new(2026, 9, 10)

    test "not computable when lookback_days is nil" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: nil)
      assert_not t.computable?
      assert_empty t.days
      assert_match(/not stated/, t.summary)
    end

    test "in-window evidence is bucketed onto the correct day" do
      evidence = [ { "date" => "09/08/2026", "author" => "J. Okafor, LPN", "quote" => "note" } ]
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, evidence: evidence)
      assert t.computable?
      assert_equal 7, t.days.size
      assert_equal ARD - 6, t.first_day
      assert_equal ARD, t.last_day
      day = t.days.find { |d| d.date == Date.new(2026, 9, 8) }
      assert_equal 1, day.entries.size
      assert t.days.last.is_ard
      assert_match(/1 supporting note/, t.summary)
    end

    test "outside-window evidence is stranded, not plotted on the day strip" do
      outside = [ { "date" => "08/20/2026", "author" => "R. Bilodeau, LCSW", "quote" => "too early" } ]
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, outside_window_evidence: outside)
      assert_equal 1, t.stranded.size
      assert_equal Date.new(2026, 8, 20), t.stranded.first[:date]
      assert t.days.all? { |d| d.entries.empty? }
      assert_match(/1 note outside the window/, t.summary)
    end

    test "empty evidence renders a full day strip with every cell empty (looks sparse)" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7)
      assert_equal 7, t.days.size
      assert t.days.all? { |d| d.entries.empty? }
      assert_equal 0, t.evidence_count
      assert t.sparse?
      assert_match(/No supporting evidence/, t.summary)
    end

    test "illustrative flag is exposed for the rulebook item-page usage" do
      t = LookbackTimeline.new(ard: ARD, lookback_days: 7, illustrative: true)
      assert t.illustrative?
    end
  end
end
