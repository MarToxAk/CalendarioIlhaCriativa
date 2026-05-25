Rails.application.routes.draw do
  # Admin auth routes (at root — Authentication concern uses /session path)
  resource :session, only: [ :new, :create, :destroy ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
    resources :clients, only: [ :index, :show, :new, :create, :edit, :update ] do
      member do
        post :rotate_token
      end
    end
    resources :artes, except: [:show], controller: 'artes'
  end

  # Artes global index
  namespace :admin do
    resources :artes
  end

  # Portal do cliente
  scope "/c/:token", as: :client do
    root to: "client/home#index"
    resource :session, only: [ :new, :create, :destroy ], controller: "client/sessions"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
