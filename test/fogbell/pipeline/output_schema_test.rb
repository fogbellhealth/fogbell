require "test_helper"

module Fogbell
  module Pipeline
    class OutputSchemaTest < ActiveSupport::TestCase
      def schema = OutputSchema.build

      def each_node(node, &block)
        block.call(node)
        case node
        when Hash then node.each_value { |v| each_node(v, &block) }
        when Array then node.each { |v| each_node(v, &block) }
        end
      end

      test "is itself a valid JSON Schema" do
        assert JSONSchemer.valid_schema?(schema), JSONSchemer.validate_schema(schema).to_a.inspect
      end

      test "contains no keywords the structured-output API rejects" do
        each_node(schema) do |node|
          next unless node.is_a?(Hash)

          leftovers = node.keys & OutputSchema::UNSUPPORTED
          assert_empty leftovers, "found #{leftovers} in #{node.inspect[0, 120]}"
          assert_not node["type"].is_a?(Array), "type arrays must become anyOf: #{node.inspect[0, 120]}"
          assert_equal false, node["additionalProperties"], "objects need additionalProperties false: #{node.inspect[0, 120]}" if node["type"] == "object" && node["properties"]
        end
      end

      test "omits pipeline-filled fields and makes every remaining property required" do
        assert_not_includes schema["properties"].keys, "provenance_summary"
        assert_not_includes schema["properties"].keys, "version"
        assert_equal schema["properties"].keys.sort, schema["required"].sort
        assert_includes schema["required"], "lookback_source"
        assert_includes schema["required"], "not_found"
      end

      test "optional fields become nullable" do
        lookback_source = schema["properties"]["lookback_source"]
        assert lookback_source["anyOf"].any? { |alt| alt["type"] == "null" }, lookback_source.inspect
        quote = schema["$defs"]["citation"]["properties"]["quote"]
        assert quote["anyOf"].any? { |alt| alt["type"] == "null" }
        assert_equal({ "type" => "object", "additionalProperties" => false }, schema["properties"]["supportive_documentation"]["properties"]["state"].except("description"))
      end

      test "the canned stub response satisfies the output schema" do
        response = JSON.parse(file_fixture("llm/x0100_response.json").read)
        errors = JSONSchemer.schema(schema).validate(response).map { |e| e["error"] }
        assert_empty errors
      end
    end
  end
end
