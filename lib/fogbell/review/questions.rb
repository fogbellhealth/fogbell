# frozen_string_literal: true

module Fogbell
  module Review
    # Renders review/QUESTIONS.md for the web review queue: split into sections by heading
    # ("Questions for the Verifier" / "Questions for a New York reviewer") so the Maine/New York
    # qualification split stays visible, without pulling in a markdown gem for one file.
    module Questions
      Section = Data.define(:title, :intro, :items)
      Item = Data.define(:number, :html)

      class << self
        def sections(path: Rails.root.join("review/QUESTIONS.md"))
          return [] unless path.exist?

          parts = path.read.split(/^## /)
          first_body = parts.shift.sub(/\A#[^\n]*\n/, "")
          sections = [ [ "Questions for the Verifier", first_body ] ] + parts.map { |b| b.split("\n", 2) }
          sections.map { |title, body| parse_section(title, body.to_s) }
        end

        private

        def parse_section(title, body)
          lines = body.strip.split("\n")
          intro_lines = []
          intro_lines << lines.shift while lines.any? && !lines.first.match?(/^\d+\.\s/)
          items = body.strip.split(/\n(?=\d+\.\s)/).select { |b| b.match?(/^\d+\.\s/) }.map do |b|
            n = b[/^(\d+)\./, 1].to_i
            Item.new(number: n, html: to_html(b.sub(/^\d+\.\s*/, "")))
          end
          Section.new(title: title.strip, intro: to_html(intro_lines.join(" ")), items: items)
        end

        def to_html(text)
          escaped = ERB::Util.html_escape(text.strip)
          escaped.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>').gsub(/`(.+?)`/, '<code class="rounded bg-slate-100 px-1 py-0.5 text-xs">\1</code>').html_safe
        end
      end
    end
  end
end
