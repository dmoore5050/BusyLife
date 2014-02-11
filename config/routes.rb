Busylife::Application.routes.draw do
  devise_for :users, controllers: {omniauth_callbacks: 'authentications'}

  devise_scope :user do
    get 'logout', :to => 'devise/sessions#destroy'
  end

  root to: 'authentications#index'
  namespace :authentications do
    get 'reauthenticate'
  end

  resources :synchronizations, except: [:index, :show] do
    collection do
      post 'prepare'
      post 'trello_listener'
      get  'trello_listener'
      get  'evernote_listener'
      get  'map'
    end
  end

  %w( 404 422 500 ).each do |code|
    get code, :to => "errors#show", :code => code
  end


end
