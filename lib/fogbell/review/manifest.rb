# frozen_string_literal: true

module Fogbell
  module Review
    # Reads corpus/MANIFEST.md so a citation's doc key can be shown as a readable
    # document name ("RAI Manual v1.20.1") instead of the key itself.
    class Manifest
      ROW = /\A\|\s*`(?<key>[^`]+)`\s*\|\s*(?<title>[^|]*)\|\s*(?<version>[^|]*)\|/

      def self.default
        new(Rails.root.join("corpus/MANIFEST.md"))
      end

      def initialize(path)
        @titles = {}
        Pathname(path).each_line do |line|
          m = ROW.match(line) or next
          @titles[m[:key]] = display_name(m[:title].strip, m[:version].strip)
        end
      end

      # Readable name for +key+; falls back to the key so nothing is ever hidden.
      def name(key)
        @titles.fetch(key, key)
      end

      private

      # "Long-Term Care ... (RAI Manual)" + "v1.20.1, Oct 2025" -> "RAI Manual v1.20.1 (Oct 2025)"
      def display_name(title, version)
        short = title[/\(([^)]+)\)\s*\z/, 1] || title
        ver, date = version.split(",", 2).map { |s| s&.strip }
        [ short, ver, (date ? "(#{date})" : nil) ].compact.reject(&:empty?).join(" ")
      end
    end
  end
end
