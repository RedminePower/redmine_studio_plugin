# frozen_string_literal: true

Rails.application.routes.draw do
  resources :plugins, :only => [:index, :show]

  # Teams Button
  get 'teams_button/user_email/:id', to: 'teams_button#user_email'

  # Auto Close
  resources :auto_closes
end
