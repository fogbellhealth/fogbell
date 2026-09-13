module RulebookHelper
  INSTRUMENT_NAMES = { "MDS-3.0" => "MDS 3.0", "MDS-RCA" => "MDS-RCA", "MDS-AH" => "MDS-AH", "UAS-NY" => "UAS-NY" }.freeze

  # The provenance_summary.expert_review_status the JSON actually carries, upgraded to "pending"
  # when a RuleReview exists for this item that hasn't been materialized yet by
  # `rake rulebook:apply_review`. "pending" is a display-layer state only — it is never written
  # into the item JSON itself (the schema's expert_review_status enum has no such value).
  def effective_review_status(item)
    return "pending" if RuleReview.pending.for_item(item.item_id).exists?

    item.provenance_summary["expert_review_status"]
  end

  # The jurisdiction an item's own rules were extracted from: the manifest section of its
  # first source document ("Federal", "Maine", "New York"). Reused for filtering and display.
  def item_jurisdiction(item)
    doc = item.provenance_summary.dig("source_documents", 0, "doc")
    manifest.jurisdiction(doc) || "Federal"
  end

  def instrument_name(instrument)
    INSTRUMENT_NAMES.fetch(instrument, instrument)
  end

  # Numbers every unique citation on +item+ in first-appearance order (S1, S2, ...) so rules,
  # criteria and conflicts can reference them inline — the design's "§6 Sources" footnote scheme.
  def number_sources(item)
    numbers = {}
    key = ->(s) { [ s["doc"], s["loc"], s["quote"] ] }
    add = ->(s) { numbers[key.call(s)] ||= numbers.size + 1 if s.present? }
    item.federal_coding_rules.each { |r| add.call(r["source"]) }
    item.supportive_documentation.fetch("federal", []).each { |c| add.call(c["source"]) }
    item.conflicts.each { |c| c["positions"].each { |p| add.call(p["source"]) } }
    add.call(item.lookback_source)
    numbers
  end

  def source_tag(source, numbers)
    return "".html_safe if source.blank?

    n = numbers[[ source["doc"], source["loc"], source["quote"] ]]
    n ? content_tag(:span, "[S#{n}]", class: "text-xs font-semibold text-muted") : "".html_safe
  end

  def not_found_label(key)
    Fogbell::Review::Page::NOT_FOUND_LABELS.fetch(key) { key.tr("_", " ") }
  end

  def rule_item_path(item_id)
    rulebook_item_path(item_id)
  rescue ActionController::UrlGenerationError
    nil
  end

  # Every citable statement across +items+ (or a single item): coding rules, coding-level
  # definitions, and state deltas, each normalized to {text:, source:}.
  def statements(items)
    Array(items).compact.flat_map do |item|
      item.federal_coding_rules.map { |r| { text: r["rule"], source: r["source"] } } +
        item.coding_levels.map { |l| { text: "#{l['label']} — #{l['definition']}", source: l["source"] } } +
        item.state_deltas.map { |d| { text: d["delta"], source: d["source"] } }
    end
  end

  # The most specific statement across +items+ matching +pattern+ (longest text wins ties, since a
  # specific figure is usually stated at greater length than the general definition mentioning it).
  # Used to pull a cited fact (e.g. a sample size) out of a CONV item without hardcoding its text.
  def find_rule(items, pattern)
    statements(items).select { |s| s[:text] =~ pattern }.max_by { |s| s[:text].length }
  end

  def rule_fact(items, pattern)
    r = find_rule(items, pattern)
    return content_tag(:span, "not stated in the public document", class: "text-slate-400 italic") unless r

    safe_join([ r[:text], " ", content_tag(:span, cite(r[:source]), class: "text-xs text-slate-500") ])
  end
end
