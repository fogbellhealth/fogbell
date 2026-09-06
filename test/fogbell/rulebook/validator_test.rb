require "test_helper"

module Fogbell
  module Rulebook
    class ValidatorTest < ActiveSupport::TestCase
      def fixture(name)
        JSON.parse(file_fixture("rulebook/#{name}.json").read)
      end

      test "a fully cited item is valid" do
        assert_empty Validator.validate(fixture("valid_item"))
      end

      test "an item with an uncited rule fails, pointing at the rule" do
        errors = Validator.validate(fixture("uncited_rule"))
        assert errors.any? { |e| e.include?("/federal_coding_rules/1") && e.include?("source") }, errors.inspect
      end

      test "an unknown instrument fails" do
        errors = Validator.validate(fixture("unknown_instrument"))
        assert errors.any? { |e| e.include?("/instrument") }, errors.inspect
      end

      test "a lookback window without a citation fails" do
        errors = Validator.validate(fixture("lookback_without_source"))
        assert errors.any? { |e| e.include?("lookback_source") }, errors.inspect
      end

      test "a conflict with only one position fails" do
        errors = Validator.validate(fixture("one_sided_conflict"))
        assert errors.any? { |e| e.include?("/conflicts/0/positions") }, errors.inspect
      end

      test "an unknown top-level key fails" do
        errors = Validator.validate(fixture("unknown_key"))
        assert errors.any? { |e| e.include?("maine_notes") }, errors.inspect
      end

      test "valid? mirrors validate" do
        assert Validator.valid?(fixture("valid_item"))
        assert_not Validator.valid?(fixture("uncited_rule"))
      end
    end
  end
end
