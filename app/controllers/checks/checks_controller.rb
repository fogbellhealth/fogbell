module Checks
  # GET /  -> the check form (preloaded with the synthetic demo chart)
  # POST /checks -> create + enqueue, then redirect to the live result page
  # GET /checks/:id -> results, streamed in as the job finishes each item
  class ChecksController < ApplicationController
    DEFAULT_ITEMS = %w[D0150 D0160 D0500 D0600 E0100 E0200 E0300 E0800 E0900 E1000 E1100].freeze

    def new
      @check = from_worklist_assessment || from_params
      @sections = checkable_items_by_section
    end

    def create
      @check = Check.new(check_params)
      if @check.save
        RunCheckJob.perform_later(@check)
        redirect_to check_path(@check)
      else
        @sections = checkable_items_by_section
        flash.now[:alert] = @check.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @check = Check.find(params[:id])
    end

    private

    # A worklist card's "Open check" link: carries only an id, so the resident's chart/ARD/item
    # never round-trip through a URL.
    def from_worklist_assessment
      assessment = Assessment.find_by(id: params[:assessment_id])
      return nil unless assessment

      Check.new(chart_text: assessment.resident.chart_text, ard: assessment.ard,
                item_ids: [ assessment.focus_item_id ] & Fogbell::Rulebook.instance.ids)
    end

    # Direct/ad-hoc use: the synthetic demo chart, optionally with a preselected item (from a
    # rulebook item page's "run a check using this item" link).
    def from_params
      requested = Array(params.dig(:check, :item_ids)).reject(&:blank?)
      preselected = requested.presence & Fogbell::Rulebook.instance.ids
      Check.new(chart_text: Fogbell::EvidenceCheck::SyntheticChart.text, ard: Fogbell::EvidenceCheck::SyntheticChart::DEFAULT_ARD,
                item_ids: preselected.presence || (DEFAULT_ITEMS & Fogbell::Rulebook.instance.ids))
    end

    def check_params
      p = params.require(:check).permit(:chart_text, :ard, item_ids: [])
      p[:item_ids] = Array(p[:item_ids]).reject(&:blank?)
      p
    end

    def checkable_items_by_section
      Fogbell::Rulebook.instance.reject { |i| i.section == "CONV" }.group_by(&:section).sort.to_h
    end
  end
end
