# frozen_string_literal: true

Rails.application.routes.draw do
  resources :plugins, :only => [:index, :show]

  # Teams Button
  get 'teams_button/user_email/:id', to: 'teams_button#user_email'

  # Auto Close
  resources :auto_closes

  # Date Independent
  resources :date_independents

  # Review Settings
  resources :review_settings, only: [:index, :show, :create, :update, :destroy] do
    member do
      get 'users', to: 'review_setting_users#index'
      put 'users', to: 'review_setting_users#replace'
      post 'users/:user_id', to: 'review_setting_users#add', as: 'add_user'
      delete 'users/:user_id', to: 'review_setting_users#remove', as: 'remove_user'
    end
  end

  # User's Review Settings
  get 'users/:id/review_settings', to: 'user_review_settings#index', as: 'user_review_settings'
end
