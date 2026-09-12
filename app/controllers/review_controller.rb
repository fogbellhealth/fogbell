# GET  /review           -> unreviewed items, the Verifier's queue
# GET  /review/questions -> the standing question list (review/QUESTIONS.md), Maine/NY split visible
# GET  /review/:item_id  -> the markup form for one item
# PATCH /review/:item_id -> apply markup, write provenance into the item JSON, changelog it
class ReviewController < ApplicationController
  def index
    all = Fogbell::Rulebook.instance.to_a
    @status = params[:status].presence || "unreviewed"
    @items = @status == "all" ? all : all.select { |i| i.provenance_summary["expert_review_status"] == @status }
    @counts = all.group_by { |i| i.provenance_summary["expert_review_status"] }.transform_values(&:size)
  end

  def questions
    @sections = Fogbell::Review::Questions.sections
  end

  def show
    @item = Fogbell::Rulebook.instance.find(params[:item_id])
    raise ActionController::RoutingError, "not found" unless @item
  end

  def update
    item = Fogbell::Rulebook.instance.find(params[:item_id])
    raise ActionController::RoutingError, "not found" unless item

    outcome = Fogbell::Review::Submission.new(
      params[:item_id],
      reviewer: params[:reviewer],
      rule_verdicts: (params[:rules] || {}).to_unsafe_h,
      criterion_verdicts: (params[:criteria] || {}).to_unsafe_h
    ).apply!
    Fogbell::Rulebook.reset!

    label = outcome.status == "verified" ? "Verified" : "Marked disputed"
    flash[:notice] = "#{label}: #{outcome.item_id}#{" — #{outcome.disputes.join('; ')}" if outcome.disputes.any?}"
    redirect_to review_path
  end
end
