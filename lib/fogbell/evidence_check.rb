# frozen_string_literal: true

module Fogbell
  # The evidence checker: chart text + ARD + selected rulebook items -> per-item support status,
  # in-window evidence, outside-window warnings, gaps and a cited "why". One model call per check.
  module EvidenceCheck
    class Error < StandardError; end
    class InvalidResponse < Error; end

    class << self
      # Test seam: replace with a lambda returning any object that responds to #complete/#model.
      attr_writer :llm_builder

      def llm
        (@llm_builder || -> { Pipeline::Llm::AnthropicClient.new }).call
      end
    end
  end
end
