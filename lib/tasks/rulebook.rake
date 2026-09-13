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
#   HINT        one-line description of what the item covers, for ids that name no literal manual item (CONV-*)
#   CONVENTIONS=0  do not prepend the instrument's promoted CONV-* rules to the prompt (default: prepend when any exist)
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
      hint: ENV["HINT"].presence,
      conventions: ENV["CONVENTIONS"] == "0" ? [] : Fogbell::Rulebook.conventions_for(ENV.fetch("INSTRUMENT", "MDS-3.0"), ENV.fetch("DOC_ID") { File.basename(doc, ".*") }),
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

  # Layer one state's document onto promoted items:
  #   bin/rails rulebook:layer_state DOC=corpus/maine/mainecare-101-iii-67.txt DOC_ID=mainecare-101-iii-67 STATE=ME ITEMS=D0500,D0600
  #   DOC / DOC_ID / STATE (two letters) / ITEMS (ids, or ALL)                      required
  #   ITEMS_DIR  where the promoted items live                          default: rulebook/items
  #   OUT        where merged items are written for review               default: tmp/layer_state
  #   MODE auto|text|pdf, MODEL, LLM, DRY_RUN=1, FORCE=1 as for extract
  desc "Layer a state document onto promoted items (state criteria, deltas, fed/state conflicts); see file header"
  task layer_state: :environment do
    doc = ENV["DOC"] or abort "DOC=<path> is required"
    state = ENV["STATE"].to_s.upcase
    abort "STATE=<two-letter code> is required" unless state.match?(/\A[A-Z]{2}\z/)
    items_dir = Pathname(ENV.fetch("ITEMS_DIR", Fogbell::Rulebook.items_dir.to_s))
    items = ENV["ITEMS"].to_s == "ALL" ? items_dir.glob("*.json").map { |p| p.basename(".json").to_s }.sort : ENV["ITEMS"].to_s.split(",").map(&:strip).reject(&:empty?)
    abort "ITEMS=<ID,ID,...> or ITEMS=ALL is required" if items.empty?

    llm =
      case ENV.fetch("LLM", "anthropic")
      when "stub" then Fogbell::Pipeline::Llm::StubClient.new(ENV.fetch("STUB_RESPONSE", Rails.root.join(Fogbell::Pipeline::Llm::StubClient::DEFAULT_RESPONSE)))
      when "anthropic" then Fogbell::Pipeline::Llm::AnthropicClient.new(model: ENV.fetch("MODEL", Fogbell::Pipeline::Llm::AnthropicClient::DEFAULT_MODEL))
      else abort "LLM must be anthropic or stub"
      end

    layerer = Fogbell::Pipeline::StateLayerer.new(
      doc: doc, doc_id: ENV.fetch("DOC_ID") { File.basename(doc, ".*") }, state: state, llm: llm,
      items_dir: items_dir, out_dir: ENV.fetch("OUT", Rails.root.join("tmp/layer_state").to_s),
      mode: ENV.fetch("MODE", "auto"), force: ENV["FORCE"] == "1", logger: $stdout
    )

    failures = 0
    items.each do |item_id|
      if ENV["DRY_RUN"] == "1"
        prompt = layerer.prompt_for(item_id)
        puts "===== SYSTEM (#{item_id}) =====", prompt.system, "", "===== USER (#{item_id}) =====", prompt.user, ""
        next
      end

      layerer.run(item_id)
    rescue Fogbell::Pipeline::Rejected => e
      failures += 1
      warn "REJECTED #{e.message}"
    rescue Fogbell::Pipeline::Error, Fogbell::Rulebook::Error => e
      failures += 1
      warn "ERROR #{item_id}: #{e.message}"
    end

    abort "#{failures} of #{items.size} item(s) failed" if failures.positive?
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

  # Materializes pending RuleReview rows (submitted via the web app's /review) into
  # rulebook/items/*.json — the only path that writes review markup into the corpus. Refuses to
  # run against an uncommitted rulebook/ tree so the resulting diff is always clean and reviewable
  # on its own. DRY_RUN=1 prints the plan without writing or updating any RuleReview.
  desc "Materialize pending RuleReview rows into rulebook/items/*.json (DRY_RUN=1 to preview)"
  task apply_review: :environment do
    items_dir = Pathname(ENV.fetch("ITEMS_DIR", Fogbell::Rulebook.items_dir.to_s))
    git_root = ENV.fetch("GIT_ROOT", Rails.root.to_s)
    git_check_path = ENV.fetch("GIT_CHECK_PATH", "rulebook")
    applier = Fogbell::Review::ApplyReview.new(items_dir: items_dir, changelog: Fogbell::Pipeline::Changelog.new(items_dir.join("../changelog.md")))
    plan = applier.plan

    if plan.empty?
      puts "No pending reviews."
      next
    end

    puts "Pending review plan:"
    plan.each do |item_id, grouping|
      puts "  #{item_id}: #{grouping[:winners].size} target(s) to apply#{" (#{grouping[:superseded].size} superseded)" if grouping[:superseded].any?}"
      grouping[:winners].each { |r| puts "    #{r.target}: #{r.verdict} (#{r.reviewer.email}, #{r.submitted_at.to_date.iso8601})" }
    end

    if ENV["DRY_RUN"] == "1"
      puts "\nDRY_RUN=1 — nothing written."
      next
    end

    dirty = `git -C #{git_root} status --porcelain -- #{git_check_path}`.strip
    if dirty.present?
      abort "\n#{git_check_path}/ has uncommitted changes — commit or stash them first, so this task's diff is reviewable on its own:\n#{dirty}"
    end

    results = applier.apply!
    puts "\nApplied:"
    results.each { |r| puts "  #{r.item_id}: #{r.applied} applied, #{r.superseded} superseded -> #{r.status}" }
  end
end
