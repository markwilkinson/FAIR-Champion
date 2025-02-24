require 'rack/test'
require 'rspec-openapi'

require_relative '../app/application_controller'  # Adjust the path to your Sinatra app file

RSpec.describe Champion do
  include Rack::Test::Methods

  # This tells Rack::Test which app to test
  def app
    MyApp.new
  end

  describe 'GET /champion/sets' do
    it 'returns a list of known sets' do
      get '/champion/sets'
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)['message']).to eq('Hello, world!')
    end
  end

  describe 'POST /champion/sets/' do
    it 'creates a new set' do
      post '/champion/sets/', { name: 'mynewset' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      # should return location or sometihing..
      # expect(JSON.parse(last_response.body)['message']).to eq('!')
    end
  end
end