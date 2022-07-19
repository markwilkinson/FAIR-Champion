require 'swagger/blocks'
require 'sinatra/json'
require 'sinatra'
require 'sinatra/base'
require_relative './configuration.rb'
require_relative './models.rb'
require_relative './routes.rb'
require_relative './swagger.rb'

class Api < Sinatra::Application
  # include Swagger::Blocks



  run! if app_file == $0
end

