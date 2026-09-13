# GET /residents/:id -> a resident's chart and assessment history. Facility-domain only, scoped
# to current_user's own facility — see FacilityAreaPolicy and CLAUDE.md's role-model note.
class ResidentsController < ApplicationController
  before_action { authorize :facility_area, policy_class: FacilityAreaPolicy }

  def show
    @resident = require_facility!.residents.find(params[:id])
  end
end
