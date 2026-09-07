# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # The model's answer for one check. Structured-output compatible (no patterns/formats);
    # the same hash is used with json_schemer to validate what came back.
    module ResponseSchema
      STATUSES = %w[supported partial unsupported not_applicable].freeze

      EVIDENCE = {
        "type" => "object", "additionalProperties" => false,
        "required" => %w[date author quote],
        "properties" => {
          "date" => { "type" => "string", "description" => "Date exactly as written in the chart, or 'not recorded'." },
          "author" => { "type" => "string", "description" => "Author/discipline exactly as written, or 'not recorded'." },
          "quote" => { "type" => "string", "description" => "Verbatim excerpt from the chart." }
        }
      }.freeze

      ITEM = {
        "type" => "object", "additionalProperties" => false,
        "required" => %w[item_id status suggested_coding rationale evidence outside_window_evidence gaps chart_today_action rules_applied],
        "properties" => {
          "item_id" => { "type" => "string" },
          "status" => { "type" => "string", "enum" => STATUSES },
          "suggested_coding" => { "type" => "string", "description" => "The conservative code the in-window evidence supports, or what the chart's worksheet intends and whether it is supported." },
          "rationale" => { "type" => "string", "description" => "Two or three plain sentences: what the record shows and does not show." },
          "evidence" => { "type" => "array", "items" => EVIDENCE, "description" => "In-window documentation that supports the coding." },
          "outside_window_evidence" => { "type" => "array", "items" => EVIDENCE, "description" => "Documentation that exists but is dated outside the window; listed, never counted." },
          "gaps" => { "type" => "array", "items" => { "type" => "string" }, "description" => "What a reviewer would flag as missing." },
          "chart_today_action" => { "anyOf" => [ { "type" => "string" }, { "type" => "null" } ], "description" => "Contemporaneous charting of care actually occurring now; null when none applies." },
          "rules_applied" => { "type" => "array", "items" => { "type" => "integer" }, "description" => "Rule numbers [Rn] relied on." }
        }
      }.freeze

      def self.build
        {
          "type" => "object", "additionalProperties" => false,
          "required" => %w[items overall_note],
          "properties" => {
            "items" => { "type" => "array", "items" => ITEM },
            "overall_note" => { "type" => "string", "description" => "One or two sentences for the nurse; draft for review." }
          }
        }
      end

      def self.validate(data)
        JSONSchemer.schema(build).validate(data).map { |e| "#{e['data_pointer'].presence || '/'}: #{e['type']}" }
      end
    end
  end
end
