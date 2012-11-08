Shaders::Application.routes.draw do
  root :to => 'home#index'

  resources :color_schemes
  resource :editor
end
