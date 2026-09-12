Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # The evidence checker is the whole app for now. Controllers live under app/controllers/checks/.
  scope module: :checks do
    root "checks#new"
    resources :checks, only: %i[new create show]
  end

  # The rulebook browser: the corpus itself, made demoable.
  get "rulebook", to: "rulebook#index"
  get "rulebook/jurisdictions", to: "rulebook#jurisdictions"
  get "rulebook/:item_id", to: "rulebook#show", as: :rulebook_item
end
