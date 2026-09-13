# frozen_string_literal: true

module Fogbell
  # Presents one item's look-back window for one ARD as a day-by-day strip, for the
  # app/views/shared/_lookback_timeline partial. Always renders 2 lead days before the window
  # plus the window itself (a 7-day window -> 9 columns), per design_handoff_fogbell/README.md.
  # Evidence dated earlier than that lead-in is not plotted on the strip (it is still listed in
  # the surrounding evidence text) — the timeline is a small, fixed-size strip, not a full history.
  class LookbackTimeline
    LEAD_DAYS = 2

    Day = Data.define(:date, :in_window, :is_ard, :is_today, :entries, :outside_entries) do
      def plotted? = entries.any? || outside_entries.any?
    end

    attr_reader :ard, :lookback_days

    def initialize(ard:, lookback_days:, evidence: [], outside_window_evidence: [], today: Date.current)
      @ard = ard
      @lookback_days = lookback_days
      @evidence = evidence || []
      @outside_window_evidence = outside_window_evidence || []
      @today = today
      @window = EvidenceCheck::Window.new(ard, lookback_days)
    end

    def computable? = @window.computable?
    def window_first_day = @window.first_day
    def last_day = @window.last_day
    def range_first_day = computable? ? window_first_day - LEAD_DAYS : nil
    def column_count = computable? ? lookback_days + LEAD_DAYS : 0

    def days
      return [] unless computable?

      (range_first_day..last_day).map do |date|
        in_window = date >= window_first_day
        Day.new(
          date: date, in_window: in_window, is_ard: date == last_day, is_today: date == @today,
          entries: in_window ? @evidence.select { |e| @window.parse(e["date"]) == date } : [],
          outside_entries: in_window ? [] : @outside_window_evidence.select { |e| @window.parse(e["date"]) == date }
        )
      end
    end

    def evidence_count = @evidence.size
    def stranded_count = @outside_window_evidence.size
    def sparse? = computable? && evidence_count <= 1

    # Real evidence that exists but falls earlier than the rendered lead-in — still true, still
    # listed elsewhere on the page, just not something this small a strip can plot.
    def unplotted_count
      return 0 unless computable?

      (evidence_count + stranded_count) - days.sum { |d| d.entries.size + d.outside_entries.size }
    end

    def summary
      return "Look-back window not stated for this item; evidence dates are not plotted." unless computable?

      parts = [ "#{lookback_days}-day window, #{window_first_day.strftime('%b %-d')} through #{last_day.strftime('%b %-d, %Y')} (ARD)." ]
      parts << (evidence_count.zero? ? "No supporting evidence found in the window." : "#{pluralize_note(evidence_count, 'supporting note')} in the window.")
      parts << "#{pluralize_note(stranded_count, 'note')} outside the window and not counted." if stranded_count.positive?
      parts.join(" ")
    end

    private

    def pluralize_note(n, word) = "#{n} #{word}#{'s' unless n == 1}"
  end
end
