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

      HEADING = /\A##\s+([^(]+?)\s*(?:\(|$)/

      def initialize(path)
        @titles = {}
        @jurisdictions = {}
        section = nil
        Pathname(path).each_line do |line|
          if (h = HEADING.match(line))
            section = h[1].strip
            next
          end
          m = ROW.match(line) or next
          @titles[m[:key]] = display_name(m[:title].strip, m[:version].strip)
          @jurisdictions[m[:key]] = section
        end
      end

      # The manifest section a document is filed under ("Federal", "Maine", ...); nil when unknown.
      def jurisdiction(key) = @jurisdictions[key]

      def federal?(key) = jurisdiction(key).to_s.casecmp?("Federal")

      # Readable name for +key+; falls back to the key so nothing is ever hidden.
      def name(key)
        @titles.fetch(key, key)
      end

      private

      # "Long-Term Care ... (RAI Manual)" + "v1.20.1, Oct 2025" -> "RAI Manual v1.20.1 (Oct 2025)".
      # A trailing parenthetical is used as the short name only when it reads like one (a few words,
      # no commas); otherwise the text after the last colon, else the whole title. The version column
      # is cut at its first clause so notes never leak into a citation.
      def display_name(title, version)
        paren = title[/\(([^)]+)\)\s*\z/, 1]
        short = if paren && paren.split.size <= 4 && !paren.include?(",") then paren
                elsif title.include?(": ") then title.split(": ").last.sub(/\s*\([^)]*\)\s*\z/, "")
                else title
                end
        ver = version.split(/;|\(| per /).first.to_s.strip
        ver, date = ver.split(",", 2).map { |s| s&.strip }
        [ short, ver, (date.present? ? "(#{date})" : nil) ].compact.reject(&:empty?).join(" ").strip
      end
    end
  end
end
