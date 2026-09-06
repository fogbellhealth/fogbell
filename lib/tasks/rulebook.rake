# frozen_string_literal: true

# Rulebook pipeline. Run locally, by hand. Never runs in production.
#
#   bin/rails rulebook:extract DOC=corpus/federal/rai-manual-v1.20.1-secD.pdf DOC_ID=rai-manual-v1.20.1 ITEMS=D0500,D0600 MODE=pdf
#   bin/rails rulebook:review_pages [OUT=review] [ITEMS=D0500,D0600]
#
# Arguments are environment variables (rake bracket args split on commas):
#   DOC         path to the source document (.pdf or .txt)                         required
#   ITEMS       comma-separated item ids                                           required
#   DOC_ID      manifest key used in citations (corpus/MANIFEST.md)     default: DOC basename without extension
#   INSTRUMENT  instrument enum value                                    default: MDS-3.0
#   OUT         output directory                                        default: rulebook/items
#   MODE        auto | text | pdf  (pdf sends the document to the API natively; auto does so
#               only when pdftotext yields almost no text, i.e. a form/scanned PDF)   default: auto
#   WINDOW      pages of context on each side of a matching page          default: 2
#   MODEL       Anthropic model id                                        default: claude-opus-5
#   LLM         anthropic | stub  (stub replays STUB_RESPONSE, no API key needed)   default: anthropic
#   STUB_RESPONSE path to the canned response for LLM=stub    default: test/fixtures/files/llm/x0100_response.json
#   DRY_RUN=1   print the rendered prompt and exit without calling the model
#   FORCE=1     overwrite an existing item file
#
# Requires `pdftotext` (poppler) for text extraction from PDFs: `brew install poppler`.
# Schema-invalid model output is never written to OUT; it is saved under tmp/rulebook_rejects/.
# The changelog is appended beside OUT (OUT/../changelog.md), so smoke runs into tmp/ leave rulebook/changelog.md alone.

namespace :rulebook do
  desc "Extract item(s) from a corpus document into schema-valid rulebook JSON (see file header for args)"
  task extract: :environment do
    doc = ENV["DOC"] or abort "DOC=<path> is required"
    items = ENV["ITEMS"].to_s.split(",").map(&:strip).reject(&:empty?)
    abort "ITEMS=<ID,ID,...> is required" if items.empty?

    llm =
      case ENV.fetch("LLM", "anthropic")
      when "stub"
        Fogbell::Pipeline::Llm::StubClient.new(ENV.fetch("STUB_RESPONSE", Rails.root.join(Fogbell::Pipeline::Llm::StubClient::DEFAULT_RESPONSE)))
      when "anthropic"
        Fogbell::Pipeline::Llm::AnthropicClient.new(model: ENV.fetch("MODEL", Fogbell::Pipeline::Llm::AnthropicClient::DEFAULT_MODEL))
      else
        abort "LLM must be anthropic or stub"
      end

    extractor = Fogbell::Pipeline::Extractor.new(
      doc: doc,
      doc_id: ENV.fetch("DOC_ID") { File.basename(doc, ".*") },
      instrument: ENV.fetch("INSTRUMENT", "MDS-3.0"),
      out_dir: ENV.fetch("OUT", Fogbell::Rulebook.items_dir.to_s),
      mode: ENV.fetch("MODE", "auto"),
      window: Integer(ENV.fetch("WINDOW", "2")),
      force: ENV["FORCE"] == "1",
      llm: llm,
      logger: $stdout
    )

    failures = 0
    items.each do |item_id|
      if ENV["DRY_RUN"] == "1"
        prompt = extractor.prompt_for(item_id)
        puts "===== SYSTEM (#{item_id}) =====", prompt.system, "", "===== USER (#{item_id}) =====", prompt.user, ""
        next
      end

      extractor.run(item_id)
    rescue Fogbell::Pipeline::Rejected => e
      failures += 1
      warn "REJECTED #{e.message}"
    rescue Fogbell::Pipeline::Error, Fogbell::Rulebook::Error => e
      failures += 1
      warn "ERROR #{item_id}: #{e.message}"
    end

    abort "#{failures} of #{items.size} item(s) failed" if failures.positive?
  end

  desc "Merge state-specific deltas into existing items and surface fed/state conflicts (not implemented)"
  task layer_state: :environment do
    abort "rulebook:layer_state is not implemented yet — see backlog.md"
  end

  desc "Generate review/<ID>.md one-pagers for the Verifier from the promoted rulebook (OUT=review, ITEMS=ID,ID)"
  task review_pages: :environment do
    out_dir = Pathname(ENV.fetch("OUT", Rails.root.join("review").to_s))
    registry = Fogbell::Rulebook.load
    wanted = ENV["ITEMS"].to_s.split(",").map(&:strip).reject(&:empty?)
    items = wanted.empty? ? registry.items : wanted.map { |id| registry.fetch(id) }
    abort "no items in #{Fogbell::Rulebook.items_dir}" if items.empty?

    manifest = Fogbell::Review::Manifest.default
    out_dir.mkpath
    items.each do |item|
      path = out_dir.join("#{item.item_id}.md")
      path.write(Fogbell::Review::Page.new(item, manifest: manifest).render)
      puts "wrote #{path.relative_path_from(Rails.root)}"
    end
  end

  desc "Run evals/scenarios against the rulebook (not implemented)"
  task evals: :environment do
    abort "rulebook:evals is not implemented yet — see backlog.md"
  end
end
