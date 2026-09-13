class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # The public demo spends money on every check. When DEMO_PASSWORD is set (production on Render),
  # the whole app sits behind HTTP basic auth; /up (Rails::HealthController) is unaffected.
  before_action :require_demo_password

  # Every real page requires a signed-in user; Devise's own controllers (sign in/out) are exempt,
  # or nobody could ever reach the sign-in form.
  before_action :authenticate_user!, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :deny_cross_domain_access

  private

  # Defense in depth beneath the policy checks: any facility-scoped query built from this can
  # never return another facility's rows, and raises the same 404 a genuinely missing record
  # would if the current user somehow has no facility at all (e.g. a misconfigured dev account).
  def require_facility!
    current_user.facility || raise(ActiveRecord::RecordNotFound, "no facility for #{current_user.id}")
  end

  def require_demo_password
    password = ENV["DEMO_PASSWORD"].presence or return
    authenticate_or_request_with_http_basic("Fogbell demo") { |_user, given| ActiveSupport::SecurityUtils.secure_compare(given.to_s, password) }
  end

  # A policy denial is a domain boundary, not a "you're not allowed to click that button" — it
  # reads as "this doesn't exist for you," the same as a 404 would for genuinely absent data.
  def deny_cross_domain_access
    render plain: "Not found", status: :not_found
  end
end
