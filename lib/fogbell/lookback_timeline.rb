# frozen_string_literal: true

module Fogbell
  # Presents one item's look-back window for one ARD as a day-by-day strip, for the
  # app/views/shared/_lookback_timeline partial. Evidence outside the window is kept separate
  # and rendered visibly stranded — that separation is the point of the component.
  class LookbackTimeline
    Day = Data.define(:date, :entries, :is_ard)

    attr_reader :ard, :lookback_days, :item_name

    def initialize(ard:, lookback_days:, item_name: nil, evidence: [], outside_window_evidence: [], illustrative: false)
      @ard = ard
      @lookback_days = lookback_days
      @item_name = item_name
      @evidence = evidence || []
      @outside_window_evidence = outside_window_evidence || []
      @illustrative = illustrative
      @window = EvidenceCheck::Window.new(ard, lookback_days)
    end

    def illustrative? = @illustrative
    def computable? = @window.computable?
    def first_day = @window.first_day
    def last_day = @window.last_day

    # One Day per calendar day in the window, first_day..last_day inclusive, each carrying the
    # evidence entries (if any) whose parsed date falls on it.
    def days
      return [] unless computable?

      (first_day..last_day).map do |date|
        entries = @evidence.select { |e| @window.parse(e["date"]) == date }
        Day.new(date: date, entries: entries, is_ard: date == last_day)
      end
    end

    # Outside-window entries, each with its parsed date attached (nil if unparseable), oldest first.
    def stranded
      @outside_window_evidence.map { |e| { entry: e, date: @window.parse(e["date"]) } }
                               .sort_by { |s| s[:date] || Date.new(0) }
    end

    def evidence_count = @evidence.size
    def stranded_count = @outside_window_evidence.size
    def sparse? = computable? && evidence_count <= 1

    def summary
      return "Look-back window not stated for this item; evidence dates are not plotted." unless computable?

      parts = [ "#{lookback_days}-day window, #{first_day.strftime('%b %-d')} through #{last_day.strftime('%b %-d, %Y')} (ARD)." ]
      parts << (evidence_count.zero? ? "No supporting evidence found in the window." : "#{pluralize_note(evidence_count, 'supporting note')} in the window.")
      parts << "#{pluralize_note(stranded_count, 'note')} outside the window and not counted." if stranded_count.positive?
      parts.join(" ")
    end

    private

    def pluralize_note(n, word) = "#{n} #{word}#{'s' unless n == 1}"
  end
end
