Rails.application.routes.draw do
  # Admin auth routes (at root — Authentication concern uses /session path)
  resource :session, only: [ :new, :create, :destroy ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
    resources :clients, only: [ :index ]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
