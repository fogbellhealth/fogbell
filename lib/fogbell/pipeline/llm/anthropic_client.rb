# frozen_string_literal: true

require "anthropic"
require "base64"

module Fogbell
  module Pipeline
    module Llm
      # Thin wrapper over the Anthropic Ruby SDK for one extraction call.
      # Text mode sends the rendered [PAGE n] chunks; PDF mode also attaches the
      # document itself as a base64 document block (native PDF input; 600 pages /
      # 32 MB request limit) with a prompt-cache breakpoint. Output is constrained with structured outputs.
      class AnthropicClient
        DEFAULT_MODEL = "claude-opus-5"
        MAX_TOKENS = 32_000

        attr_reader :model

        def initialize(model: DEFAULT_MODEL, client: nil, max_tokens: MAX_TOKENS)
          @model = model
          @client = client
          @max_tokens = max_tokens
        end

        def complete(system:, user:, output_schema:, pdf: nil, pdf_title: nil, document_text: nil)
          # Streamed so max_tokens can exceed what the SDK allows for a blocking request; the
          # accumulated message is the same shape as a non-streaming response.
          stream = client.messages.stream(
            model: @model,
            max_tokens: @max_tokens,
            system_: system,
            thinking: { type: :adaptive },
            output_config: { format: { type: :json_schema, schema: output_schema } },
            messages: [ { role: :user, content: content_blocks(user, pdf, pdf_title, document_text) } ]
          )
          stream.until_done
          message = stream.accumulated_message
          check_stop_reason!(message)
          Response.new(text: text_of(message), model: message.model.to_s, usage: message.usage.to_h)
        rescue Anthropic::Errors::NotFoundError => e
          raise Error, "model #{@model.inspect} was not found (#{e.message.lines.first&.strip}). " \
                       "Check the id or pass MODEL=<id>; see `bin/rails rulebook:extract` header for the default."
        rescue Anthropic::Errors::AuthenticationError => e
          raise Error, "authentication failed (#{e.message.lines.first&.strip}). Export ANTHROPIC_API_KEY or run with LLM=stub."
        rescue Anthropic::Errors::RateLimitError => e
          raise Error, "rate limited by the API; wait and retry (#{e.message.lines.first&.strip})"
        rescue Anthropic::Errors::APIStatusError => e
          raise Error, "API error #{e.status} #{e.type}: #{e.message.lines.first&.strip}"
        rescue Anthropic::Errors::APIConnectionError => e
          raise Error, "could not reach the API: #{e.message.lines.first&.strip}"
        end

        private

        def client
          @client ||= begin
            raise Error, "ANTHROPIC_API_KEY is not set. Export it, or run with LLM=stub." if ENV["ANTHROPIC_API_KEY"].to_s.empty? && ENV["ANTHROPIC_AUTH_TOKEN"].to_s.empty?

            Anthropic::Client.new
          end
        end

        def content_blocks(user, pdf, pdf_title, document_text = nil)
          blocks = []
          # A long text document (e.g. a converted .docx rule) gets the same cache breakpoint as a PDF.
          blocks << { type: :text, text: document_text, cache_control: { type: :ephemeral } } if document_text
          if pdf
            # Cache breakpoint: system prompt + document form a stable prefix shared by every item
            # extracted from the same document; only the short user text after it varies.
            blocks << { type: :document, title: pdf_title,
                        source: { type: :base64, media_type: :"application/pdf", data: Base64.strict_encode64(pdf) },
                        cache_control: { type: :ephemeral } }
          end
          blocks << { type: :text, text: user }
        end

        def check_stop_reason!(message)
          case message.stop_reason
          when :refusal
            details = message.stop_details
            raise Error, "the model declined this request (#{details&.category}): #{details&.explanation}"
          when :max_tokens
            raise Error, "output truncated at #{@max_tokens} tokens; narrow WINDOW or raise max_tokens"
          end
        end

        def text_of(message)
          message.content.select { |block| block.type == :text }.map(&:text).join
        end
      end
    end
  end
end
