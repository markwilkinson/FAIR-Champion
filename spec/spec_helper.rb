require 'rack/test'
require_relative '../app/controllers/configuration'
require_relative '../app/controllers/application_controller'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Set Host header globally for all Rack::Test requests
  config.before(:each) do
    header "host", "localhost"
  end
end