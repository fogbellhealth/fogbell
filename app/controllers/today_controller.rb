# GET / -> the worklist: open assessment windows ordered by days remaining, the product's shape.
# Facility-domain only, and scoped to current_user's own facility — a rulebook-domain user's scope
# here is empty even before the policy check runs (current_user.facility is nil for them).
class TodayController < ApplicationController
  def index
    authorize :facility_area, policy_class: FacilityAreaPolicy

    @facility = current_user.facility
    @assessments = current_user.facility ? current_user.facility.assessments.open_windows.includes(:resident, :check) : Assessment.none
    @needs_charting = @assessments.count { |a| %w[partial unsupported].include?(a.finding&.dig("status")) }
    @closing_this_week = @assessments.count { |a| a.days_remaining <= 7 }

    review_item = Fogbell::Rulebook.instance.detect { |i| i.section == "CONV" && i.citations.any? { |c| c["quote"].to_s.match?(/decrease in the Direct Care Rate/i) } }
    findings = @assessments.filter_map(&:finding)
    @projection = Fogbell::EvidenceCheck::AuditProjection.new(findings, review_item: review_item) if findings.any?
  end
end
