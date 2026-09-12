Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # The worklist is the product's shape: a time-ordered list of closing windows, not a form.
  root "today#index"

  # The evidence checker is reachable from a worklist card or directly for ad-hoc use.
  scope module: :checks do
    resources :checks, only: %i[new create show]
  end

  # The rulebook browser: the corpus itself, made demoable.
  get "rulebook", to: "rulebook#index"
  get "rulebook/jurisdictions", to: "rulebook#jurisdictions"
  get "rulebook/:item_id", to: "rulebook#show", as: :rulebook_item

  # Detected changes in the corpus's source documents.
  get "changes", to: "changes#index"

  # The Verifier's/reviewer's markup surface, and the standing question list.
  get "review", to: "review#index"
  get "review/questions", to: "review#questions"
  get "review/:item_id", to: "review#show", as: :review_item
  patch "review/:item_id", to: "review#update"
end
