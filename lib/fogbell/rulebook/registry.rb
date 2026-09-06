# frozen_string_literal: true

module Fogbell
  module Rulebook
    # Read-only collection of Items loaded from a directory of JSON files.
    class Registry
      include Enumerable

      # Reads, validates and freezes every *.json under +dir+.
      def self.load(dir)
        items = dir.glob("*.json").sort.map { |path| load_file(path) }
        new(items)
      end

      def self.load_file(path)
        data = JSON.parse(path.read)
        errors = Validator.validate(data)
        raise InvalidItem, "#{path}:\n  #{errors.join("\n  ")}" if errors.any?

        expected = path.basename(".json").to_s
        if data["item_id"] != expected
          raise InvalidItem, "#{path}: filename #{expected}.json does not match item_id #{data['item_id']}"
        end

        Item.from_hash(data)
      rescue JSON::ParserError => e
        raise InvalidItem, "#{path}: not valid JSON (#{e.message})"
      end

      attr_reader :items

      def initialize(items)
        @items = items.sort_by(&:item_id).freeze
        @by_id = @items.index_by(&:item_id).freeze
        freeze
      end

      def each(&) = @items.each(&)
      def ids = @by_id.keys
      def find(item_id) = @by_id[item_id]
      def fetch(item_id) = @by_id.fetch(item_id)
      def size = @items.size
      def empty? = @items.empty?
    end
  end
end
