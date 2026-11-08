Rails.application.routes.draw do
  # Vite's dev server is bound to localhost, so keep the app on the same host.
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "groups#index"
  get "sign-up", to: "registrations#new", as: :sign_up
  post "sign-up", to: "registrations#create"
  get "sign-in", to: "sessions#new", as: :sign_in
  post "sign-in", to: "sessions#create"
  delete "session", to: "sessions#destroy"
  resource :profile, only: [ :show, :update ]
  resources :groups, only: [ :index, :new, :create, :show, :destroy ] do
    collection do
      get "join", action: :join_form
      post "join", action: :join
    end
    post "invitation/reset", to: "invitations#reset", as: :reset_invitation
    post "members/:user_id/promote", to: "memberships#promote", as: :member_promote
    delete "members/:user_id", to: "memberships#destroy", as: :member
  end
end
