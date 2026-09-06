# frozen_string_literal: true

require "erb"

module Fogbell
  module Pipeline
    # Renders lib/prompts/<name>.md.erb into a system prompt and a user message.
    # The template is a reviewable file; the two parts are separated by a line
    # containing only `=== USER ===`.
    class PromptTemplate
      SEPARATOR = /^=== USER ===\s*$/
      Prompt = Data.define(:system, :user)

      def self.default
        new(Rails.root.join("lib/prompts/extract_item.md.erb"))
      end

      attr_reader :path

      def initialize(path)
        @path = Pathname(path)
        raise Error, "prompt template not found: #{@path}" unless @path.file?
      end

      def render(**locals)
        rendered = ERB.new(@path.read, trim_mode: "-").result_with_hash(locals)
        system, user = rendered.split(SEPARATOR, 2)
        raise Error, "#{@path} has no `=== USER ===` separator" if user.nil?

        Prompt.new(system: system.strip, user: user.strip)
      end
    end
  end
end
