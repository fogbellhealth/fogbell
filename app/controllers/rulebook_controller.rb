# GET /rulebook               -> index, grouped by instrument then section, filterable
# GET /rulebook/:item_id      -> one item, full detail with sources
# GET /rulebook/jurisdictions -> cross-jurisdiction comparison (the corpus's thesis, in one page)
class RulebookController < ApplicationController
  include ApplicationHelper
  include RulebookHelper

  def index
    all = Fogbell::Rulebook.instance.to_a
    @counts = {
      total: all.size,
      with_state_layers: all.count { |i| i.state_deltas.any? },
      with_conflicts: all.count { |i| i.conflicts.any? },
      pending_review: all.count { |i| i.provenance_summary["expert_review_status"] == "unreviewed" }
    }

    @jurisdictions = all.map { |i| item_jurisdiction(i) }.uniq.sort
    @statuses = all.map { |i| i.provenance_summary["expert_review_status"] }.uniq.sort

    items = all
    items = items.select { |i| item_jurisdiction(i) == params[:jurisdiction] } if params[:jurisdiction].present?
    items = items.select { |i| i.provenance_summary["expert_review_status"] == params[:status] } if params[:status].present?

    @grouped = items.group_by(&:instrument).sort.to_h.transform_values { |is| is.group_by(&:section).sort.to_h }
  end

  def show
    @item = Fogbell::Rulebook.instance.find(params[:item_id])
    raise ActionController::RoutingError, "not found" unless @item
  end

  def jurisdictions
    all = Fogbell::Rulebook.instance.to_a
    @mds_items = all.select { |i| i.instrument == "MDS-3.0" && i.section != "CONV" }
    @mds_with_state_layer = @mds_items.select { |i| i.state_deltas.any? }
    @me_review = Fogbell::Rulebook.instance.find("CONV-ME-MDS-REVIEW")
    @me_case_mix = Fogbell::Rulebook.instance.find("CONV-ME-CASE-MIX")
    @ny_areas = all.select { |i| i.item_id.start_with?("CONV-NY-OMIG-ALP-") }.sort_by(&:item_id)
    @with_conflicts = all.select { |i| i.conflicts.any? }
  end
end
