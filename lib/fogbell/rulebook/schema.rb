# frozen_string_literal: true

require "json_schemer"

module Fogbell
  module Rulebook
    # rulebook/schema.json, parsed once. THE contract; changes get extra scrutiny.
    module Schema
      class << self
        def path
          Rulebook.schema_path
        end

        def json
          @json ||= JSON.parse(path.read).freeze
        end

        def schemer
          @schemer ||= JSONSchemer.schema(json, format: true)
        end

        def reset!
          @json = nil
          @schemer = nil
        end
      end
    end
  end
end
