# GET /assessments/:id -> one assessment's window, finding and timeline. Facility-domain only,
# scoped to current_user's own facility — see FacilityAreaPolicy and CLAUDE.md's role-model note.
class AssessmentsController < ApplicationController
  before_action { authorize :facility_area, policy_class: FacilityAreaPolicy }

  def show
    @assessment = require_facility!.assessments.find(params[:id])
  end
end
