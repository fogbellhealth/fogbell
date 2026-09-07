# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # An item's observation window ending on the ARD: ARD plus the (days - 1) preceding calendar
    # days, the counting rule the manual states for its standard window. Items with no stated
    # window have no computable range; evidence dates are then left to the model's judgement.
    class Window
      attr_reader :ard, :days

      def initialize(ard, days)
        @ard = ard
        @days = days
      end

      def computable? = days.is_a?(Integer) && days.positive?
      def first_day = computable? ? ard - (days - 1) : nil
      def last_day = ard

      def text
        return "not stated in the manual for this item; use the item's own notes" unless computable?

        "#{days} days: #{first_day.strftime('%b %-d, %Y')} through #{last_day.strftime('%b %-d, %Y')} (the ARD counts as day 1; count back #{days - 1} more days)"
      end

      # True/false when the date parses, nil when it cannot be parsed (or no window).
      def includes?(date_text)
        return nil unless computable?

        d = parse(date_text)
        d && d >= first_day && d <= last_day
      end

      DATE_PATTERNS = [ /(\d{4})-(\d{1,2})-(\d{1,2})/, %r{(\d{1,2})/(\d{1,2})/(\d{4})}, %r{(\d{1,2})/(\d{1,2})/(\d{2})\b} ].freeze

      def parse(text)
        return nil if text.blank?

        if (m = text.match(DATE_PATTERNS[0])) then Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
        elsif (m = text.match(DATE_PATTERNS[1])) then Date.new(m[3].to_i, m[1].to_i, m[2].to_i)
        elsif (m = text.match(DATE_PATTERNS[2])) then Date.new(2000 + m[3].to_i, m[1].to_i, m[2].to_i)
        else
          Date.parse(text)
        end
      rescue ArgumentError, Date::Error
        nil
      end
    end
  end
end
