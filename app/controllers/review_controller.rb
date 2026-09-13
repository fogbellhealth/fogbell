# GET  /review           -> the queue, unreviewed by default
# GET  /review/questions -> the standing question list (review/QUESTIONS.md), Maine/NY split visible
# GET  /review/:item_id  -> the markup form for one item
# POST /review/:item_id  -> submit markup — writes a RuleReview row (status "pending"), never
#                            touches rulebook/items/*.json. Only `rake rulebook:apply_review` does
#                            that; see CLAUDE.md and lib/tasks/rulebook.rake.
# Rulebook-domain only (verifier/staff) — see RulebookAreaPolicy. This surface never touches a
# resident, chart, assessment, or check; there is no query here that could.
class ReviewController < ApplicationController
  include RulebookHelper

  before_action { authorize :rulebook_area, policy_class: RulebookAreaPolicy }

  def index
    all = Fogbell::Rulebook.instance.to_a
    @status = params[:status].presence || "unreviewed"
    @items = @status == "all" ? all : all.select { |i| effective_review_status(i) == @status }
    @counts = all.group_by { |i| effective_review_status(i) }.transform_values(&:size)
  end

  def questions
    @sections = Fogbell::Review::Questions.sections
  end

  def show
    @item = Fogbell::Rulebook.instance.find(params[:item_id])
    raise ActionController::RoutingError, "not found" unless @item

    @pending = RuleReview.pending.for_item(@item.item_id).index_by(&:target)
  end

  def create
    item = Fogbell::Rulebook.instance.find(params[:item_id])
    raise ActionController::RoutingError, "not found" unless item

    count = 0
    ActiveRecord::Base.transaction do
      (params[:rules] || {}).each do |idx, v|
        RuleReview.create!(item_id: item.item_id, target: "rule:#{idx}", verdict: verdict_for(v), notes: v[:note], reviewer: current_user)
        count += 1
      end
      (params[:criteria] || {}).each do |idx, v|
        RuleReview.create!(item_id: item.item_id, target: "criterion:#{idx}", verdict: verdict_for(v), notes: v[:note], reviewer: current_user)
        count += 1
      end
    end

    flash[:notice] = "Submitted #{count} #{'markup'.pluralize(count)} for #{item.item_id}. Pending until a maintainer runs rulebook:apply_review."
    redirect_to review_path
  end

  private

  def verdict_for(v)
    { "correct" => "correct", "wrong" => "incorrect", "different" => "applied_differently" }.fetch(v[:verdict], v[:verdict])
  end
end
