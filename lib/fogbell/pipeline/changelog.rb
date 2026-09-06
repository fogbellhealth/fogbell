# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Appends one line per pipeline action to rulebook/changelog.md (append-only).
    class Changelog
      def self.default
        new(Rulebook.root.join("changelog.md"))
      end

      attr_reader :path

      def initialize(path)
        @path = Pathname(path)
      end

      def append(action:, item_id:, doc:, model:, pages: nil, note: nil, date: Date.today)
        parts = [ date.iso8601, action, item_id, "doc=#{doc} pages=#{format_pages(pages)} model=#{model}" ]
        parts << note if note
        @path.dirname.mkpath
        @path.open("a") { |f| f.puts "- #{parts.join(' · ')}" }
      end

      private

      def format_pages(pages)
        return "all" if pages.nil? || pages.empty?

        pages.slice_when { |a, b| b != a + 1 }.map { |run| run.size > 1 ? "#{run.first}-#{run.last}" : run.first.to_s }.join(",")
      end
    end
  end
end
