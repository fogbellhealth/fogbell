# frozen_string_literal: true

module Fogbell
  module Pipeline
    module Llm
      # Returns a canned response from a file. Lets the entire extract path run with no
      # API key (LLM=stub) and gives tests a deterministic model.
      class StubClient
        DEFAULT_RESPONSE = "test/fixtures/files/llm/x0100_response.json"

        Call = Data.define(:system, :user, :output_schema, :pdf, :document_text)

        attr_reader :calls

        def initialize(response_path = Rails.root.join(DEFAULT_RESPONSE), text: nil)
          @text = text || Pathname(response_path).read
          @calls = []
        end

        def model = "stub"

        def complete(system:, user:, output_schema:, pdf: nil, pdf_title: nil, document_text: nil)
          @calls << Call.new(system: system, user: user, output_schema: output_schema, pdf: pdf, document_text: document_text)
          Response.new(text: @text, model: model, usage: {})
        end
      end
    end
  end
end
