# require 'sinatra'
require_relative 'configuration'
require 'sinatra/base'
require 'require_all'
require_relative 'routes'
require_rel '../../lib'
require_rel '../views'

module Champion

  class ChampionApp < Sinatra::Base
    # before do
    #   puts "Request Host: #{request.host}"
    #   puts "Full ENV: #{request.env.inspect}"
    # end
    # Debug middleware
    # puts "Middleware: #{middleware.map(&:inspect).join(', ')}" if ENV['DEBUG']
    # disable :protection  # Explicitly disable any protection
    set_routes
  end
end

Champion::ChampionApp.run! if __FILE__ == $0
