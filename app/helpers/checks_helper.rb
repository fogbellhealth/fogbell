module ChecksHelper
  def cite(source)
    return "" if source.blank?

    "#{manifest.name(source['doc'])}, #{source['loc']}"
  end

  def jurisdiction_badge(source)
    j = manifest.jurisdiction(source["doc"])
    return if j.blank? || manifest.federal?(source["doc"])

    badge("provisional", label: "#{j} layer — provisional pending expert review")
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
