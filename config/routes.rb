Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # The evidence checker is the whole app for now. Controllers live under app/controllers/checks/.
  scope module: :checks do
    root "checks#new"
    resources :checks, only: %i[new create show]
  end
end
