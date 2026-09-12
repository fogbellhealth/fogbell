# GET / -> the worklist: open assessment windows ordered by days remaining, the product's shape.
class TodayController < ApplicationController
  def index
    @facility = Facility.first
    @assessments = Assessment.open_windows.includes(:resident, :check)
    @needs_charting = @assessments.count { |a| %w[partial unsupported].include?(a.finding&.dig("status")) }
    @closing_this_week = @assessments.count { |a| a.days_remaining <= 7 }

    review_item = Fogbell::Rulebook.instance.detect { |i| i.section == "CONV" && i.citations.any? { |c| c["quote"].to_s.match?(/decrease in the Direct Care Rate/i) } }
    findings = @assessments.filter_map(&:finding)
    @projection = Fogbell::EvidenceCheck::AuditProjection.new(findings, review_item: review_item) if findings.any?
  end
end
