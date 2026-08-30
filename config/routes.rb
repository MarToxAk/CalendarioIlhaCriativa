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
      resource :whatsapp_instance, only: [ :create ], controller: "whatsapp_instances" do
        post :refresh_qr
        post :verify
        post :adopt
        post :reconnect
      end
      resources :whatsapp_groups, only: [ :index, :show ], controller: "whatsapp_groups" do
        collection do
          post :sync
          get  :sync_status
        end
      end
      resources :divulgacoes, only: [ :index, :new, :create, :show ] do
        member { patch :cancel }
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

  # JSON API — versioned namespace
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      namespace :admin do
        resource :session, only: [ :create ]   # POST /api/v1/admin/session
        resources :clients, only: [ :index, :create ]
        resources :artes, only: [ :index, :create ] do
          resources :approval_responses, only: [ :index ]
        end
      end

      namespace :client do
        resource :session, only: [ :create ]   # POST /api/v1/client/session
        resources :artes, only: [ :index, :show ] do
          resources :approval_responses, only: [ :create ]
        end
      end

      namespace :ai do
        resources :artes, only: [ :index, :create ]
        resources :clients, only: [] do
          get :summary, on: :member
        end
      end
    end
  end

  # Webhook autenticado do Evolution (fase 26) — sem CSRF/sessão; o controller
  # chega no plano 26-03. A rota entra aqui, ANTES do health check, para o
  # surface inteiro da fase já existir (interface-first, uma vez só).
  post "/webhooks/evolution", to: "webhooks/evolution#create"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
