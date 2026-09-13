# GET / -> routes signed-in users by role domain. A facility user (nurse/don) lands on the
# worklist; a rulebook user (verifier/staff) lands on the review queue. They are meant to feel
# like different applications — see CLAUDE.md's "Role model" note.
class HomeController < ApplicationController
  def index
    redirect_to(current_user.rulebook_domain? && !current_user.facility_domain? ? review_path : today_path)
  end
end
