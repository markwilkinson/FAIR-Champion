require 'sinatra'
require "sinatra/base"
require "sinatra/json"

class MyApp < Sinatra::Application

  # define a route that uses the helper
  get '/' do
    json :foo => 'bar'
  end
  run! if app_file == $0

  # The rest of your modular application code goes here...
end

