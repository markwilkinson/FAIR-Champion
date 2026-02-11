# app/controllers/application_controller.rb
require_relative 'configuration'
require 'sinatra/base'
require 'require_all'
require_relative 'routes'
require_rel '../../lib'
require_rel '../views'

module Champion
  class ChampionApp < Sinatra::Base
    # Call set_routes only in app context
    set_routes unless ENV['RACK_ENV'] == 'test' # Avoid in test environment
  end
end
