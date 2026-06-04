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
    resources :artes do
      member do
        patch :mark_revised
      end
    end
    resources :approvals, only: [ :index ]
    resources :calendar,  only: [ :index ]
    resource :settings, only: [ :show ] do
      patch :update_password, on: :member
      patch :update_agency,   on: :member
    end
  end

  # Portal do cliente
  scope "/c/:token", as: :client do
    root to: "client/home#index"
    resource :session, only: [ :new, :create, :destroy ], controller: "client/sessions"
    resources :artes, only: [ :show ], controller: "client/artes" do
      resources :responses, only: [ :create ], controller: "client/responses"
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
