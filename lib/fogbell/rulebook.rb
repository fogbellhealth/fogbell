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
    end
  end
end
