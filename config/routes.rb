Busylife::Application.routes.draw do
  devise_for :users, controllers: {omniauth_callbacks: 'authentications'}

  devise_scope :user do
    get 'logout', :to => 'devise/sessions#destroy'
  end

  root to: 'authentications#index'

  resource :notebooks, only: [:create, :update, :destroy]
  resource :notebook_boards, only: [:destroy]
  resources :synchronizations do
    collection do
      post 'trello_listener'
      get  'trello_listener'
      get  'evernote_listener'
      get  'pingdom_listener'
      get  'map'
    end
  end

  mount Resque::Server => '/resque'
end
