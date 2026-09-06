require "test_helper"

module Fogbell
  module Rulebook
    class RegistryTest < ActiveSupport::TestCase
      def with_items_dir(*fixture_names)
        Dir.mktmpdir("rulebook-items") do |dir|
          fixture_names.each do |name|
            source = file_fixture("rulebook/#{name}.json")
            item_id = JSON.parse(source.read).fetch("item_id")
            FileUtils.cp(source, File.join(dir, "#{item_id}.json"))
          end
          yield Pathname.new(dir)
        end
      end

      test "loads a valid item into a frozen plain Ruby object" do
        with_items_dir("valid_item") do |dir|
          registry = Fogbell::Rulebook.load(dir)
          assert_equal [ "X0100" ], registry.ids

          item = registry.fetch("X0100")
          assert_kind_of Item, item
          assert item.frozen?
          assert_equal "Fog Visibility Check", item.item_name
          assert_equal "MDS-3.0", item.instrument
          assert_equal 7, item.lookback_days
          assert_equal 2, item.federal_coding_rules.size
          assert_equal "p. 3", item.federal_coding_rules.last.fetch("source").fetch("loc")
          assert_equal 1, item.conflicts.size
          assert_equal [ "case_mix_relevance" ], item.not_found
          assert item.citations.all? { |c| c["doc"] == "fake-manual" }
          assert_operator item.citations.size, :>=, 8
        end
      end

      test "find returns nil for unknown ids, fetch raises" do
        with_items_dir("valid_item") do |dir|
          registry = Fogbell::Rulebook.load(dir)
          assert_nil registry.find("Z9999")
          assert_raises(KeyError) { registry.fetch("Z9999") }
        end
      end

      test "an item with an uncited rule refuses to load" do
        with_items_dir("uncited_rule") do |dir|
          error = assert_raises(InvalidItem) { Fogbell::Rulebook.load(dir) }
          assert_match(/X0100\.json/, error.message)
          assert_match(%r{/federal_coding_rules/1}, error.message)
        end
      end

      test "an item with an unknown instrument refuses to load" do
        with_items_dir("unknown_instrument") do |dir|
          error = assert_raises(InvalidItem) { Fogbell::Rulebook.load(dir) }
          assert_match(%r{/instrument}, error.message)
        end
      end

      test "a filename that disagrees with item_id refuses to load" do
        Dir.mktmpdir("rulebook-items") do |dir|
          FileUtils.cp(file_fixture("rulebook/valid_item.json"), File.join(dir, "G0110A.json"))
          error = assert_raises(InvalidItem) { Fogbell::Rulebook.load(Pathname.new(dir)) }
          assert_match(/G0110A\.json.*X0100/, error.message)
        end
      end

      test "an empty items directory loads an empty registry" do
        Dir.mktmpdir("rulebook-items") do |dir|
          assert_empty Fogbell::Rulebook.load(Pathname.new(dir)).items
        end
      end

      test "the committed rulebook loads and is valid" do
        assert_kind_of Registry, Fogbell::Rulebook.instance
      end
    end
  end
end
