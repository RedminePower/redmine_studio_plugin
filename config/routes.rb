# frozen_string_literal: true

Rails.application.routes.draw do
  resources :plugins, :only => [:index, :show]
end
