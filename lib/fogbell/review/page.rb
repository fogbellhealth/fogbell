# frozen_string_literal: true

module Fogbell
  module Review
    # Renders one rulebook Item as a markdown review page for the Verifier.
    # Plain English only: no JSON field names, no schema vocabulary. Every rule,
    # level, criterion and conflict position is footnoted with document name,
    # printed page label and the verbatim quote, so she can pull the manual and check.
    class Page
      CHECKBOXES = "☐ correct   ☐ wrong (how?)   ☐ auditors apply it differently (how?)"

      # Plain-English names for the fields the extractor may report as not found.
      NOT_FOUND_LABELS = {
        "lookback_days" => "the look-back window",
        "lookback_source" => "a citation for the look-back window",
        "supportive_documentation.federal" => "what the chart must show to support this item",
        "state_deltas" => "state-specific differences (none are in the federal manual)",
        "common_audit_citations" => "commonly cited audit findings",
        "case_mix_relevance" => "whether this item affects the case-mix classification",
        "case_mix_relevance.source" => "a citation for the case-mix relevance",
        "case_mix_relevance.level" => "whether this item affects the case-mix classification",
        "conflicts" => "conflicting passages (none found)",
        "supportive_documentation.state" => "state-specific documentation requirements"
      }.freeze

      def initialize(item, manifest: Manifest.default)
        @item = item
        @manifest = manifest
        @notes = []      # [ [doc_name, loc, quote] ]
        @note_index = {} # key -> footnote number
      end

      def render
        @lines = []
        header
        lookback
        coding_levels
        coding_rules
        documentation
        conflicts
        state_deltas
        not_found
        review_block
        sources
        @lines.join("\n") + "\n"
      end

      private

      def item = @item
      def out(text = "") = @lines << text

      def header
        p = item.provenance_summary || {}
        docs = Array(p["source_documents"]).map { |d| @manifest.name(d["doc"]) }.uniq.join(", ")
        out "# #{item.item_id} — #{item.item_name}"
        out
        out "*#{instrument_name} · Section #{item.section} · extracted #{p['extracted_at']} from #{docs} · status: #{p['expert_review_status'] || 'unreviewed'} · rulebook version #{item.version}*"
        out
        out "This page was generated from the manual by software and has not yet been checked by a person. Every statement below carries a source number; the sources are listed at the end with the exact wording from the manual. Please mark anything that is wrong, incomplete, or applied differently by Maine's auditors."
        out
      end

      def instrument_name
        { "MDS-3.0" => "MDS 3.0", "MDS-RCA" => "MDS-RCA", "MDS-AH" => "MDS-AH" }.fetch(item.instrument, item.instrument)
      end

      def lookback
        out "## Look-back window"
        out
        if item.lookback_days.nil?
          out "**Not stated in the manual for this item.**"
        else
          out "**#{item.lookback_days} days**#{cite(item.lookback_source)}"
        end
        out
        out plain(item.lookback_notes) unless item.lookback_notes.to_s.empty?
        window_conflicts = item.conflicts.select { |c| c["resolution"].to_s.downcase.include?("dual-window") || c["topic"].to_s =~ /window|look-?back|period/i }
        if window_conflicts.any?
          out
          out "> **Note:** the manual states more than one time period for this item. See the *Conflicts* section below."
        end
        out
      end

      def coding_levels
        return if item.coding_levels.empty?

        out "## Coding levels"
        out
        out "| Code | Meaning | What it means in the manual | Source |"
        out "|---|---|---|---|"
        item.coding_levels.each do |l|
          out "| #{md(l['code'])} | #{md(l['label'])} | #{md(l['definition'])} | #{cite(l['source']).strip} |"
        end
        out
      end

      def coding_rules
        out "## Coding rules"
        out
        if item.federal_coding_rules.empty?
          out "*No coding rules were found for this item.*"
        else
          item.federal_coding_rules.each_with_index do |r, i|
            out "#{i + 1}. #{r['rule']}#{cite(r['source'])}"
          end
        end
        out
      end

      def documentation
        federal = item.supportive_documentation.fetch("federal", [])
        state = item.supportive_documentation.fetch("state", {})
        out "## What the chart must show"
        out
        if federal.empty? && state.values.all?(&:empty?)
          out "*The manual does not state documentation requirements for this item.*"
        else
          federal.each_with_index do |c, i|
            out "#{i + 1}. #{c['criterion']} *(importance to an auditor: #{c['audit_weight']})*#{cite(c['source'])}"
            out "   #{c['notes']}" if c["notes"]
          end
          state.each do |st, criteria|
            next if criteria.empty?
            out
            out "**#{st} adds:**"
            criteria.each { |c| out "- #{c['criterion']} *(#{c['audit_weight']})*#{cite(c['source'])}" }
          end
        end
        out
      end

      def conflicts
        return if item.conflicts.empty?

        out "## ⚠️ Conflicts — please read carefully"
        out
        out "The manual (or two documents) say different things here. Both sides are shown; nothing has been dropped."
        out
        item.conflicts.each do |c|
          out "> **#{c['topic']}**"
          out ">"
          c["positions"].each do |pos|
            out "> - *#{authority_name(pos['authority'])}:* #{pos['claim']}#{cite(pos['source'])}"
          end
          out ">"
          out "> Status: #{c['resolution']}"
          out
        end
      end

      def authority_name(a)
        return "Federal manual" if a == "federal"
        return "Maine" if a == "ME"
        @manifest.name(a)
      end

      def state_deltas
        return if item.state_deltas.empty?

        out "## State differences"
        out
        item.state_deltas.each { |d| out "- **#{d['state']}:** #{d['delta']}#{cite(d['source'])}" }
        out
      end

      def not_found
        return if item.not_found.empty?

        out "## Not found in the manual"
        out
        out "The software looked for the following and could not find them on this item's pages. Blank is honest; nothing was guessed."
        out
        item.not_found.each { |k| out "- #{NOT_FOUND_LABELS.fetch(k) { k.tr('_', ' ') }}" }
        out
      end

      def review_block
        out "## Your review"
        out
        out "For each numbered coding rule above:"
        out
        item.federal_coding_rules.each_index { |i| out "- Rule #{i + 1}: #{CHECKBOXES}" }
        federal = item.supportive_documentation.fetch("federal", [])
        if federal.any?
          out
          out "For each documentation requirement:"
          out
          federal.each_index { |i| out "- Requirement #{i + 1}: #{CHECKBOXES}" }
        end
        out
        out "Anything missing that an auditor would look for? ______________________________________________"
        out
      end

      def sources
        return if @notes.empty?

        out "## Sources"
        out
        @notes.each_with_index do |(doc, loc, quote), i|
          line = "[^#{i + 1}]: #{doc}, #{loc}"
          line += " — “#{quote}”" if quote && !quote.empty?
          out line
        end
      end

      # Returns "[^n]" for a citation, registering it as a footnote; "" when there is none.
      def cite(source)
        return "" if source.nil?

        doc = @manifest.name(source["doc"])
        key = [ doc, source["loc"], source["quote"] ]
        n = @note_index[key] ||= (@notes << key).size
        "[^#{n}]"
      end

      # The extractor sometimes writes pipeline vocabulary into free text; keep the page in plain English.
      def plain(text)
        text.to_s.gsub("NOT_FOUND", "Not found")
      end

      def md(text)
        text.to_s.gsub("|", "\\|").gsub("\n", " ")
      end
    end
  end
end
