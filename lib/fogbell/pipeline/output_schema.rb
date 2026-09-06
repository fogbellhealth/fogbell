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
