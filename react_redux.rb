run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'react-rails'

    gem 'devise'
    gem 'pundit'
    gem 'simple_token_authentication'

    gem 'autoprefixer-rails'
    gem 'font-awesome-sass'
    gem 'simple_form'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  RUBY
end

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

# Assets
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
run 'curl -L https://github.com/dogaruemiliano/rails-stylesheet/archive/master.zip > stylesheets.zip'
run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/rails-stylesheet-master app/assets/stylesheets'

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Layout
########################################
if Rails.version < "6"
  scripts = <<~HTML
    <%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>
        <%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>
  HTML
  gsub_file('app/views/layouts/application.html.erb', "<%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>", scripts)
end
gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>")
style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)

# Flashes
########################################
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="close" data-dismiss="alert" aria-label="Close">
        <span aria-hidden="true">&times;</span>
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="close" data-dismiss="alert" aria-label="Close">
        <span aria-hidden="true">&times;</span>
      </button>
    </div>
  <% end %>
HTML

run 'curl -L https://raw.githubusercontent.com/dogaruemiliano/rails-components/master/templates/shared/_navbar.html.erb > app/views/shared/_navbar.html.erb'

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML

    <%= render 'shared/navbar' %>
    <%= render 'shared/flashes' %>
  HTML
end

# README
########################################
markdown_file_content = <<-MARKDOWN
Rails app generated with [dogaruemiliano/rails-templates](https://github.com/dogaruemiliano/rails-TEMPLATES).
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install', '--bootstrap')
  generate(:controller, 'pages', 'contact', '--no-test-framework')

  # Routes
  ########################################
  route "root to: 'static#main'"
  route """
      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          # YOUR API ROUTES
        end
      end
  """

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  inject_into_file 'app/models/user.rb', after: 'class User < ApplicationRecord' do
    <<~RUBY
      \n\tacts_as_token_authenticatable
    RUBY
  end

  generate(:migration, "AddTokenToUsers", "authentication_token:string{30}:uniq")

  # Pundit install
  ########################################
  generate('pundit:install')

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
      #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}
      before_action :authenticate_user!
      include Pundit

      # Pundit: white-list approach.
      after_action :verify_authorized, except: :index, unless: :skip_pundit?
      after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

      # Uncomment when you *really understand* Pundit!
      # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
      # def user_not_authorized
      #   flash[:alert] = "You are not authorized to perform this action."
      #   redirect_to(root_path)
      # end

      private

      def skip_pundit?
        devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)|(^static$)/
      end
    end
  RUBY

  # migrate + devise views with bootstrap responsive
  ########################################
  rails_command 'db:migrate'

  run 'curl -L https://github.com/dogaruemiliano/rails-components/archive/master.zip > components.zip'
  run 'unzip components.zip -d app/views && rm components.zip &&  mv app/views/rails-components-master/templates/devise app/views/devise && rm -fr app/views/rails-components-master'

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :contact ]

      def contact
      end
    end
  RUBY

  # API Controller
  ########################################
  run 'mkdir -p app/controllers/api/v1'
  run 'curl -L https://raw.githubusercontent.com/dogaruemiliano/rails-TEMPLATES/master/code/base_controller.rb > app/controllers/api/v1/base_controller.rb'

  # (REACT) Static Controller
  ########################################
  file 'app/controllers/static_controller.rb', <<~RUBY
    class StaticController < ApplicationController

      def main
      end
    end
  RUBY

  file 'app/views/static/main.html.erb', <<~HTML
    <%= content_tag :div, id: 'root', data: { current_user: current_user} do %>
    <% end %>
  HTML

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # React & Redux + dependencies
  ########################################
  run 'yarn add history react-router-dom react-bootstrap'
  run 'yarn add redux react-redux redux-devtools-extension redux-logger redux-promise'
  rails_command 'webpacker:install'
  rails_command 'webpacker:install:react'
  generate('react:install')

  ##### Actions
  run 'mkdir -p app/javascript/packs/main-react-app/actions'
  file 'app/javascript/packs/main-react-app/actions/index.js', <<~JS
    // import { ACTION_TYPE, actionItself } from './file'

    // export { ACTION_TYPE, actionItself }
  JS

  ##### Components
  run 'mkdir app/javascript/packs/main-react-app/components'
  run 'touch app/javascript/packs/main-react-app/components/.gitkeep'

  ##### Containers
  run 'mkdir app/javascript/packs/main-react-app/containers'
  run 'touch app/javascript/packs/main-react-app/containers/.gitkeep'

  ##### Reducers
  run 'mkdir app/javascript/packs/main-react-app/reducers'
  file 'app/javascript/packs/main-react-app/reducers/index.js', <<~JS
    import { combineReducers } from 'redux'

    // Import all of the reducers for this app
    const identityReducer = (state = null) => state


    // Combine reducers
    const rootReducer = combineReducers({
      changeMe: identityReducer
    })

    export default rootReducer;
  JS

  ##### Store
  run 'mkdir app/javascript/packs/main-react-app/store'
  file 'app/javascript/packs/main-react-app/store/configureStore.js', <<~JS
    import { createStore, applyMiddleware, compose } from 'redux'
    import reduxPromise from 'redux-promise';
    import { createLogger } from 'redux-logger'
    import rootReducer from '../reducers'
    import { composeWithDevTools } from 'redux-devtools-extension'

    const configureStore = (preloadedState = null) => {
      const store = createStore(
        rootReducer,
        preloadedState,
        composeWithDevTools(
          applyMiddleware(reduxPromise, createLogger())
        )
      )

      if (module.hot) {
        // Enable Webpack hot module replacement for reducers
        module.hot.accept('../reducers', () => {
          store.replaceReducer(rootReducer)
        })
      }

      return store
    }

    export default configureStore;
  JS

  ##### Entry file
  file 'app/javascript/packs/main-react-app/index.jsx', <<~JSX
    import React from 'react';
    import ReactDOM from 'react-dom';
    import { Provider } from 'react-redux';
    import { BrowserRouter as Router, Route, Redirect, Switch } from 'react-router-dom'
    import { createBrowserHistory as history } from 'history'

    // import App from './components/App'
    // import '../public/stylesheet/index.scss


    import configureStore from './store/configureStore'

    const initialState = {
      //cities: []
    }


    ReactDOM.render(
      <Provider store={configureStore(initialState)}>
        <Router histroy={history}>
          <Switch>
            TODO
          </Switch>
        </Router>
      </Provider>,
      document.getElementById('root')
    );
  JSX

  # Webpacker / Yarn
  ########################################
  run 'yarn add popper.js jquery bootstrap'

  append_file 'app/javascript/packs/application.js', <<~JS


    // ----------------------------------------------------
    // Note(lewagon): ABOVE IS RAILS DEFAULT CONFIGURATION
    // WRITE YOUR OWN JS STARTING FROM HERE 👇
    // ----------------------------------------------------

    // External imports
    import "bootstrap";

    // Internal imports, e.g:
    // import { initSelect2 } from '../components/init_select2';
    import './main-react-app/index.jsx'

    document.addEventListener('turbolinks:load', () => {
      // Call your functions here, e.g:
      // initSelect2();
    });
  JS

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      const webpack = require('webpack');
      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');
      // Bootstrap 4 has a dependency over jQuery & Popper.js:
      environment.plugins.prepend('Provide',
        new webpack.ProvidePlugin({
          $: 'jquery',
          jQuery: 'jquery',
          Popper: ['popper.js', 'default']
        })
      );
    JS
  end

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/dogaruemiliano/rails-TEMPLATES/master/.rubocop.yml > .rubocop.yml'

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit with React-Redux template from https://github.com/dogaruemiliano/rails-TEMPLATES/react-redux.rb'"

  puts "*****************************************"
  puts "*****************************************"
  puts "*****************************************"
  puts "******                             ******"
  puts "******                             ******"
  puts "******                             ******"
  puts "****** Run `rails g react:install` ******"
  puts "******                             ******"
  puts "******                             ******"
  puts "******                             ******"
  puts "*****************************************"
  puts "*****************************************"
  puts "*****************************************"
end
