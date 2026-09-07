# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # Numbers every rule the model may cite (item rules, state criteria/deltas, conventions) so the
    # model returns rule numbers and the page renders the citation from the rulebook itself, never
    # from the model's memory. Corpus-agnostic: "state" content is anything cited to a document the
    # manifest files under a non-federal jurisdiction.
    class RuleSet
      Rule = Data.define(:n, :text, :source, :item_id, :kind, :jurisdiction)

      attr_reader :rules

      def initialize(items, conventions, manifest: Review::Manifest.default)
        @manifest = manifest
        @rules = []
        @by_item = {}
        items.each { |item| @by_item[item.item_id] = number_item(item) }
        @conventions = conventions.flat_map { |c| c.federal_coding_rules.map { |r| add(r["rule"], r["source"], c.item_id, "convention") } }
      end

      def for_item(item_id) = @by_item.fetch(item_id, [])
      def conventions = @conventions
      def find(n) = @rules[n - 1]

      private

      def number_item(item)
        out = item.federal_coding_rules.map { |r| add(r["rule"], r["source"], item.item_id, "rule") }
        out += item.supportive_documentation.fetch("federal", []).map { |c| add("Documentation the manual expects: #{c['criterion']}", c["source"], item.item_id, "documentation") }
        item.supportive_documentation.fetch("state", {}).each do |st, criteria|
          out += criteria.map { |c| add("#{st} documentation expectation: #{c['criterion']}", c["source"], item.item_id, "documentation") }
        end
        out += item.state_deltas.map { |d| add("#{d['state']} difference: #{d['delta']}", d["source"], item.item_id, "state_delta") }
        out
      end

      def add(text, source, item_id, kind)
        rule = Rule.new(n: @rules.size + 1, text: text, source: source, item_id: item_id, kind: kind,
                        jurisdiction: @manifest.jurisdiction(source["doc"]))
        @rules << rule
        rule
      end
    end
  end
end
