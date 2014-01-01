require 'spec_helper'
require 'email_spec'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.ignore_localhost = true
  c.configure_rspec_metadata!
  c.hook_into :webmock
end

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
end

Capybara.ignore_hidden_elements = true
Capybara.server_port = 7787

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
