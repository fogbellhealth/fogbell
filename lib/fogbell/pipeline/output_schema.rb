# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Derives the schema handed to the API's structured-output feature from
    # rulebook/schema.json, so both layers share one contract.
    #
    # Structured outputs accept a JSON Schema subset: no numeric/string constraints,
    # no patterns, no patternProperties, no if/then, and additionalProperties must be
    # false. This transform strips those, makes every property required (optional ones
    # become nullable; the extractor drops nulls before validating against the real
    # schema), removes the fields the pipeline fills itself (provenance_summary, version),
    # and reduces per-state documentation to an empty object (state layering is a
    # separate task).
    module OutputSchema
      PIPELINE_FILLED = %w[provenance_summary version].freeze
      UNSUPPORTED = %w[$schema $id minimum maximum minLength maxLength pattern patternProperties
                       minItems maxItems format allOf if then else].freeze

      class << self
        def build(schema = Rulebook::Schema.json)
          out = transform(deep_dup(schema))
          out["properties"]["supportive_documentation"]["properties"]["state"] =
            { "type" => "object", "additionalProperties" => false,
              "description" => "Always {} at extraction time; per-state criteria are layered by a separate task." }
          out["properties"]["supportive_documentation"]["required"] = %w[federal state]
          out
        end

        # Schema for one state-layering call: the three kinds of finding plus case-mix notes,
        # built from the same $defs so a layered fragment merges into a valid item.
        def build_for_layer(schema = Rulebook::Schema.json)
          cm = deep_dup(schema["properties"]["case_mix_relevance"])
          node = {
            "type" => "object", "additionalProperties" => false, "$defs" => schema["$defs"],
            "required" => %w[state_supportive_documentation state_deltas conflicts case_mix_relevance not_found],
            "properties" => {
              "state_supportive_documentation" => { "type" => "array", "items" => { "$ref" => "#/$defs/criterion" },
                                                    "description" => "Documentation the state requires or checks in the chart to support this item." },
              "state_deltas" => { "type" => "array", "items" => { "$ref" => "#/$defs/state_delta" } },
              "conflicts" => { "type" => "array", "items" => { "$ref" => "#/$defs/conflict" } },
              "case_mix_relevance" => { "anyOf" => [ cm.except("description"), { "type" => "null" } ],
                                        "description" => "Only when the document ties this item to case-mix/payment; otherwise null." },
              "not_found" => deep_dup(schema["properties"]["not_found"])
            }
          }
          transform(deep_dup(node))
        end

        private

        def transform(node)
          case node
          when Hash
            node = node.reject { |k, _| UNSUPPORTED.include?(k) }
            node = drop_pipeline_filled(node) if node["properties"] && (node["properties"].keys & PIPELINE_FILLED).any?
            node = nullable_from_type_array(node)
            node = require_everything(node) if node["type"] == "object" && node["properties"]
            node.transform_values { |v| transform(v) }
          when Array
            node.map { |v| transform(v) }
          else
            node
          end
        end

        def drop_pipeline_filled(node)
          node = node.merge("properties" => node["properties"].except(*PIPELINE_FILLED))
          node["required"] = node["required"] - PIPELINE_FILLED if node["required"]
          node
        end

        # {"type": ["integer","null"]} -> {"anyOf": [{"type":"integer"},{"type":"null"}]}
        def nullable_from_type_array(node)
          return node unless node["type"].is_a?(Array)

          rest = node.except("type")
          rest.merge("anyOf" => node["type"].map { |t| { "type" => t } })
        end

        def require_everything(node)
          required = node.fetch("required", [])
          properties = node["properties"].to_h do |name, prop|
            [ name, required.include?(name) ? prop : nullable(prop) ]
          end
          node.merge("properties" => properties, "required" => properties.keys)
        end

        def nullable(prop)
          return prop if prop["anyOf"]&.any? { |alt| alt["type"] == "null" }

          description = prop["description"]
          core = prop.except("description")
          core = core.merge("type" => "object") if core["$ref"].nil? && core["type"].nil? && core["properties"]
          wrapped = { "anyOf" => [ core, { "type" => "null" } ] }
          description ? wrapped.merge("description" => "#{description} Null when not applicable.") : wrapped
        end

        def deep_dup(value)
          JSON.parse(JSON.generate(value))
        end
      end
    end
  end
end
