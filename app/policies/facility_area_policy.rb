# Guards every facility-domain surface (Today, the check form/results, resident and assessment
# pages): every action answers the same question, does this user's role belong to the facility
# domain at all. Facility scoping itself (which facility) is a separate concern, enforced by the
# controllers' queries — see current_user.facility usage in TodayController/ChecksController.
class FacilityAreaPolicy < ApplicationPolicy
  %i[index? show? new? create?].each { |query| define_method(query) { user&.facility_domain? || false } }
end
