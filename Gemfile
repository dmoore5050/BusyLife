source 'https://rubygems.org'

gem 'rails', '~> 3.2.13'
gem 'rack', '~> 1.4.5'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'nokogiri'
gem 'pg'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'compass-rails'
  gem 'uglifier'
  gem 'therubyracer'
end

gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'haml'
gem 'simple_form'

gem 'devise', '2.2.0'
gem 'omniauth-evernote'
gem 'evernote_oauth'
gem 'omniauth-trello'
gem 'ruby-trello'

gem 'passenger'
gem 'capistrano',  '~> 3.0.0'
gem 'pry-rails'
gem 'foreman'
gem 'render_anywhere', :require => false
gem 'resque', :require => 'resque/server'

group :development do
  gem 'capistrano-rails', '~> 1.0.0'
end

group :development, :test do
  # bundler requires these gems in development
  gem "rails-footnotes"
  gem "rspec-rails", "~> 2.8"
  gem 'guard-rspec'
  gem 'guard-livereload'
  gem 'guard-shell'
  gem 'fuubar'
  gem 'awesome_print'
  gem 'binding_of_caller'
  gem 'better_errors'
end

group :test do
  gem 'capybara', :git => 'git://github.com/rud/capybara.git' # based on v1.1.1, now save_and_open_page works again
  gem 'capybara-webkit'
  gem 'evented-spec'
  gem 'email_spec'
  gem 'factory_girl_rails'
  gem 'shoulda', '~> 3.0.beta'
  gem 'vcr'
  gem 'webmock', '~> 1.8.0'
  gem 'mockingbird', '~> 0.1.1' # twitter streaming API mocking
  gem 'launchy'
  gem 'timecop'
  gem 'database_cleaner'
end

ruby '2.0.0'