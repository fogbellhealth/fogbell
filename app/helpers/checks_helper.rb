module ChecksHelper
  STATUS_STYLES = {
    "supported" => "bg-emerald-50 text-emerald-800 ring-emerald-200",
    "partial" => "bg-amber-50 text-amber-800 ring-amber-200",
    "unsupported" => "bg-rose-50 text-rose-800 ring-rose-200",
    "not_applicable" => "bg-slate-100 text-slate-700 ring-slate-200"
  }.freeze

  def status_badge(status)
    label = { "not_applicable" => "NOT APPLICABLE" }.fetch(status, status.to_s.upcase)
    tag.span(label, class: "inline-flex items-center rounded-md px-2.5 py-1 text-xs font-semibold tracking-wide ring-1 ring-inset #{STATUS_STYLES.fetch(status, STATUS_STYLES['not_applicable'])}")
  end

  def lookback_badge(item)
    text = item.lookback_days ? "#{item.lookback_days}-day window" : "window not stated"
    tag.span(text, class: "ml-2 rounded bg-slate-100 px-1.5 py-0.5 text-[11px] text-slate-600")
  end

  def manifest = @manifest ||= Fogbell::Review::Manifest.default

  def cite(source)
    return "" if source.blank?

    "#{manifest.name(source['doc'])}, #{source['loc']}"
  end

  def jurisdiction_badge(source)
    j = manifest.jurisdiction(source["doc"])
    return if j.blank? || manifest.federal?(source["doc"])

    tag.span("#{j} layer — provisional pending expert review", class: "ml-2 rounded bg-violet-50 px-1.5 py-0.5 text-[11px] font-medium text-violet-800 ring-1 ring-inset ring-violet-200")
  end

  # The rule set for a finished check, rebuilt from the rulebook so citations are never the model's.
  def rule_set_for(check)
    @rule_sets ||= {}
    @rule_sets[check.id] ||= Fogbell::EvidenceCheck::Runner.new(check, llm: nil).rule_set
  end

  def audit_projection(check)
    review_item = Fogbell::Rulebook.instance.detect { |i| i.section == "CONV" && i.citations.any? { |c| c["quote"].to_s.match?(/decrease in the Direct Care Rate/i) } }
    Fogbell::EvidenceCheck::AuditProjection.new(check.results, review_item: review_item)
  end
end
