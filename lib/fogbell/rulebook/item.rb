# frozen_string_literal: true

module Fogbell
  module Rulebook
    # A single validated rule item as an immutable plain Ruby value. Nested structures
    # are kept as frozen hashes/arrays so the shape stays exactly what the schema says.
    Item = Data.define(
      :item_id, :item_name, :section, :instrument,
      :lookback_days, :lookback_source, :lookback_notes,
      :coding_levels, :federal_coding_rules, :supportive_documentation,
      :state_deltas, :case_mix_relevance, :conflicts, :common_audit_citations,
      :not_found, :provenance_summary, :version
    ) do
      # Builds an Item from a schema-valid hash (string keys, as parsed from JSON).
      def self.from_hash(hash)
        new(**members.to_h { |m| [ m, deep_freeze(hash[m.to_s]) ] })
      end

      def self.deep_freeze(value)
        case value
        when Hash then value.each_value { |v| deep_freeze(v) }.freeze
        when Array then value.each { |v| deep_freeze(v) }.freeze
        else value.freeze
        end
      end

      # Every {doc, loc} citation anywhere in the item, in document order.
      def citations
        collect_citations(to_h.except(:provenance_summary))
      end

      def to_h
        super.transform_values(&:dup)
      end

      private

      def collect_citations(value, acc = [])
        case value
        when Hash
          acc << value if value.key?("doc") && value.key?("loc")
          value.each_value { |v| collect_citations(v, acc) }
        when Array
          value.each { |v| collect_citations(v, acc) }
        end
        acc
      end
    end
  end
end
