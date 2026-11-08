Rails.application.routes.draw do
  get "healthz", to: "health#show"
  post "graphql", to: "graphql#execute"

  # Every other GET is a page of the web app, which does its own routing.
  get "*path", to: "pages#show", constraints: ->(request) { request.format.html? }
  root to: "pages#show"
end
