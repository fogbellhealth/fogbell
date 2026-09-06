# frozen_string_literal: true

module Fogbell
  # The extraction pipeline: corpus document -> chunked pages -> Anthropic API ->
  # schema-validated rulebook item. Driven by rake tasks, run by hand, never in production.
  # Nothing in here knows about Maine or MDS; that lives in rulebook/ data and lib/prompts/.
  module Pipeline
    VERSION = "0.1.0"

    class Error < StandardError; end
    class MissingTool < Error; end
    class NoMatch < Error; end
    class AlreadyExists < Error; end

    # Raised when the model's output fails schema validation. Nothing is written to the rulebook.
    class Rejected < Error
      attr_reader :errors, :reject_path

      def initialize(item_id, errors, reject_path)
        @errors = errors
        @reject_path = reject_path
        super("#{item_id}: model output failed schema validation (#{errors.size} error(s)); " \
              "payload saved to #{reject_path}\n  #{errors.join("\n  ")}")
      end
    end

    Page = Data.define(:number, :text) do
      def chars = text.size
      def blank? = text.strip.empty?
    end
  end
end
