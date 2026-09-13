Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations, :confirmations, :unlocks, :passwords ]

  get "up" => "rails/health#show", as: :rails_health_check

  # Unauthenticated -> sign in. Authenticated -> routed by role domain (see HomeController): a
  # facility user lands on Today, a rulebook user lands on the review queue. Never the same page.
  root "home#index"
  get "today", to: "today#index", as: :today

  resources :residents, only: %i[index show]
  resources :assessments, only: [ :show ]

  # The evidence checker is reachable from a worklist card or directly for ad-hoc use.
  scope module: :checks do
    resources :checks, only: %i[new create show]
  end

  # The rulebook browser: the corpus itself, made demoable. Both domains can read it.
  get "rulebook", to: "rulebook#index"
  get "rulebook/jurisdictions", to: "rulebook#jurisdictions"
  get "rulebook/:item_id", to: "rulebook#show", as: :rulebook_item

  # Detected changes in the corpus's source documents. Both domains can read it.
  get "changes", to: "changes#index"

  # The reviewer's markup surface, and the standing question list. Rulebook domain only.
  get "review", to: "review#index"
  get "review/questions", to: "review#questions"
  get "review/:item_id", to: "review#show", as: :review_item
  post "review/:item_id", to: "review#create"
end
