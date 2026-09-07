class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # The public demo spends money on every check. When DEMO_PASSWORD is set (production on Render),
  # the whole app sits behind HTTP basic auth; /up (Rails::HealthController) is unaffected.
  before_action :require_demo_password

  private

  def require_demo_password
    password = ENV["DEMO_PASSWORD"].presence or return
    authenticate_or_request_with_http_basic("Fogbell demo") { |_user, given| ActiveSupport::SecurityUtils.secure_compare(given.to_s, password) }
  end
end
