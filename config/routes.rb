# frozen_string_literal: true

Rails.application.routes.draw do
  resources :plugins, :only => [:index, :show]

  # Info
  get 'info', to: 'info#show'

  # Activity Info
  get 'activity_infos', to: 'activity_infos#index'

  # Teams Button
  get 'teams_button/user_email/:id', to: 'teams_button#user_email'

  # Auto Close
  resources :auto_closes

  # Date Independent
  resources :date_independents

  # Studio Settings
  resources :studio_settings, only: [:index, :show, :create, :update, :destroy] do
    member do
      get 'users', to: 'studio_setting_users#index'
      put 'users', to: 'studio_setting_users#replace'
      post 'users/:user_id', to: 'studio_setting_users#add', as: 'add_user'
      delete 'users/:user_id', to: 'studio_setting_users#remove', as: 'remove_user'
      post 'restore', to: 'studio_setting_histories#restore'
    end
    resources :histories, controller: 'studio_setting_histories', only: [:index, :show, :destroy], param: :version
  end

  # Journals List (AJAX) - show_all を先に定義（:id より前にマッチさせる）
  get 'journals_list/show_all', to: 'journals_list#show_all', as: 'journals_list_show_all'
  get 'journals_list/:id', to: 'journals_list#show', as: 'journals_list_show'

  # User's Studio Settings
  get 'users/:id/studio_settings', to: 'user_studio_settings#index', as: 'user_studio_settings'
end
