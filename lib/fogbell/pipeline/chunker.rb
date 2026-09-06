# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Picks the pages worth sending for one item: every page mentioning the item's
    # root id (G0110A -> G0110, so sub-items share their parent's pages), widened by
    # +window+ pages on each side, capped at +max_chars+ (matched pages are kept first,
    # then neighbours by distance). Pages are rendered with [PAGE n] markers so the
    # model can cite `loc: "p. n"`.
    class Chunker
      Selection = Data.define(:pages, :matched) do
        def numbers = pages.map(&:number)
      end

      def initialize(pages, window: 2, max_chars: 120_000)
        @pages = pages
        @window = window
        @max_chars = max_chars
      end

      def select(item_id)
        pattern = self.class.pattern_for(item_id)
        matched = @pages.select { |page| page.text.match?(pattern) }.map(&:number)
        raise NoMatch, "no page mentions #{item_id} (looked for #{pattern.source})" if matched.empty?

        candidates = @pages.select { |page| matched.any? { |m| (page.number - m).abs <= @window } }
        ordered = candidates.sort_by { |page| [ matched.map { |m| (page.number - m).abs }.min, page.number ] }

        kept = []
        budget = @max_chars
        ordered.each do |page|
          next if page.chars > budget

          kept << page
          budget -= page.chars
        end

        Selection.new(pages: kept.sort_by(&:number), matched: matched)
      end

      # G0110A -> /\bG0110/ ; X0100 -> /\bX0100/ ; I8000 -> /\bI8000/
      def self.pattern_for(item_id)
        root = item_id[/\A[A-Z]\d{4}/] || item_id
        /\b#{Regexp.escape(root)}/
      end

      def self.render(pages)
        pages.map { |page| "[PAGE #{page.number}]\n#{page.text.strip}" }.join("\n\n")
      end
    end
  end
end
