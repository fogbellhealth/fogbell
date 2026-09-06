# frozen_string_literal: true

module Fogbell
  module Rulebook
    # Validates a parsed item hash against the schema and returns human-readable,
    # pointer-prefixed error strings such as:
    #   "/federal_coding_rules/1: object at `/federal_coding_rules/1` is missing required properties: source"
    module Validator
      class << self
        def validate(data)
          Schema.schemer.validate(data).map { |error| format(error) }
        end

        def valid?(data)
          Schema.schemer.valid?(data)
        end

        private

        def format(error)
          pointer = error["data_pointer"].to_s
          pointer = "/" if pointer.empty?
          message = error["error"] || "#{error['type']} at #{error['schema_pointer']}"
          "#{pointer}: #{message}"
        end
      end
    end
  end
end
