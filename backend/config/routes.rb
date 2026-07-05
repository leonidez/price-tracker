Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Stays unauthenticated (Rails::HealthController does not inherit from ApplicationController).
  get "up" => "rails/health#show", as: :rails_health_check

  # All API routes live under /api/v1 and require bearer-token auth (see Authenticatable).
  namespace :api do
    namespace :v1 do
      get "ping", to: "ping#show"
      resources :stores, only: :index
      resources :resolutions, only: :create
      resources :watches, only: %i[index show create update destroy]
      resources :devices, only: :create
    end
  end
end
