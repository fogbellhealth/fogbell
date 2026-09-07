# frozen_string_literal: true

module Fogbell
  # The rulebook is a directory of JSON item files (rulebook/items/*.json), validated
  # against rulebook/schema.json and loaded read-only into plain Ruby objects.
  # Git is the database: a rulebook change is a reviewed commit.
  module Rulebook
    class Error < StandardError; end
    class InvalidItem < Error; end

    class << self
      def root
        Rails.root.join("rulebook")
      end

      def items_dir
        root.join("items")
      end

      def schema_path
        root.join("schema.json")
      end

      # Loads and validates every item under +dir+. Raises InvalidItem on the first bad file.
      def load(dir = items_dir)
        Registry.load(Pathname(dir))
      end

      # The process-wide registry for the committed rulebook. Memoized; call reset! in tests.
      def instance
        @instance ||= load
      end

      def reset!
        @instance = nil
      end

      # Verbatim, cited convention quotes for +instrument+ drawn from +doc_id+: every rule of every
      # promoted section-"CONV" item whose citation points at that document. Only rules carrying a
      # verbatim quote are returned, so anything the model lifts from the preamble is verbatim by
      # construction. Scoping to the document keeps one corpus's conventions out of another's prompts.
      # Corpus-agnostic; returns [] when there are none, so extraction still runs.
      def conventions_for(instrument, doc_id, dir = items_dir)
        return [] unless dir.directory?

        load(dir).select { |i| i.section == "CONV" && i.instrument == instrument }
                 .flat_map(&:federal_coding_rules)
                 .select { |r| r.dig("source", "doc") == doc_id && r.dig("source", "quote").present? }
                 .map { |r| { "quote" => r["source"]["quote"], "rule" => r["rule"], "source" => r["source"].slice("doc", "loc") } }
                 .uniq { |r| [ r["quote"], r["source"]["loc"] ] }
      end
    end
  end
end
