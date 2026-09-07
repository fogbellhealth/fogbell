# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # Projects a single record's results onto a state's MDS review machinery, taking every number
    # from the cited verbatim quotes of a convention item (e.g. CONV-ME-MDS-REVIEW) rather than
    # from code. If the item is absent or its quotes do not state the machinery, the projection
    # is unavailable and the page says so. Methodology: unsupported items count 1, partial items
    # count PARTIAL_WEIGHT; not_applicable items are excluded from the denominator.
    class AuditProjection
      PARTIAL_WEIGHT = 0.5

      Tier = Data.define(:error_rate_min, :reduction_pct, :source)
      Fact = Data.define(:value, :source)

      attr_reader :tiers, :sample, :correction_days, :item

      def initialize(results, review_item:)
        @results = results
        @item = review_item
        quotes = review_item ? review_item.citations.select { |c| c["quote"].present? } : []
        @tiers = extract_tiers(quotes)
        @sample = extract_sample(quotes)
        @correction_days = extract_correction(quotes)
      end

      def available? = @item.present? && tiers.any?

      def checked = @results.count { |r| r["status"] != "not_applicable" }
      def unsupported = @results.count { |r| r["status"] == "unsupported" }
      def partial = @results.count { |r| r["status"] == "partial" }
      def weighted_errors = unsupported + PARTIAL_WEIGHT * partial

      def error_rate_pct
        return nil if checked.zero?

        (weighted_errors / checked * 100).round
      end

      # The most severe tier whose threshold this record's rate reaches, or nil below the lowest.
      def tier
        return nil if error_rate_pct.nil?

        tiers.select { |t| error_rate_pct >= t.error_rate_min }.max_by(&:error_rate_min)
      end

      def next_tier
        return nil if error_rate_pct.nil?

        tiers.select { |t| error_rate_pct < t.error_rate_min }.min_by(&:error_rate_min)
      end

      private

      TIER_RE = /(\d+)\s*%\)?\s*(?:decrease|reduction) in the Direct Care Rate.*?error rate of [a-z\-\s]*\((\d+)%\) or greater/im
      SAMPLE_RE = /sample of [a-z\-\s]*\((\d+)%\)[^.]*?minimum of [a-z]+ \((\d+)\) records/im
      CORRECTION_RE = /within [a-z]+ \((\d+)\) days of a written request/im

      def extract_tiers(quotes)
        quotes.filter_map do |c|
          m = c["quote"].match(TIER_RE) or next
          Tier.new(error_rate_min: m[2].to_i, reduction_pct: m[1].to_i, source: c.slice("doc", "loc", "quote"))
        end.uniq(&:error_rate_min).sort_by(&:error_rate_min)
      end

      def extract_sample(quotes)
        c = quotes.find { |q| q["quote"].match?(SAMPLE_RE) } or return nil
        m = c["quote"].match(SAMPLE_RE)
        Fact.new(value: { pct: m[1].to_i, min_records: m[2].to_i }, source: c.slice("doc", "loc", "quote"))
      end

      def extract_correction(quotes)
        c = quotes.find { |q| q["quote"].match?(CORRECTION_RE) } or return nil
        Fact.new(value: c["quote"].match(CORRECTION_RE)[1].to_i, source: c.slice("doc", "loc", "quote"))
      end
    end
  end
end
