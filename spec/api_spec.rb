# ENV['GRAPHDB_HOST'] = '128.131.169.191'
# ENV['GRAPHDB_PORT'] = '443'
# ENV['GRAPHDB_REPONAME'] = 'fdpindex-fdp'
require 'pry'
require 'rspec/openapi'
OPENAPI = 1
RSpec::OpenAPI.path = 'doc/schema.yaml'
RSpec::OpenAPI.servers = [{ url: 'https://tools.ostrails.eu' }]
RSpec::OpenAPI.enable_example = false

require 'rack/test'
require 'spec_helper'

RSpec.describe Champion::ChampionApp, type: :request do
  include Rack::Test::Methods

  # This tells Rack::Test which app to test
  def app
    Champion::ChampionApp.new
  end

  describe 'GET /champion/sets/' do
    it 'returns a list of known sets' do
      header 'accept', 'application/json'
      get '/champion/sets/'

      # puts "Status: #{last_response.status}"          # e.g., 200
      # puts "Body: #{last_response.body}" # e.g., '{"message":"Hello, world!"}'
      # puts "Headers: #{last_response.headers}"       # e.g., {"Content-Type" => "application/json"}
      # puts "Is it OK? #{last_response.ok?}"          # e.g., true      expect(last_response).to eq last_response.to_s + "c"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json.keys.first do |context|
        set = json[context]
        # "identifier": "https://tools.ostrails.eu/champion/sets/298571696",
        # "title": "All core Champion Tests",
        # "description": "Tests covering all Principles, mirroring the tests that were available from the FAIR Evaluator",
        # "creator": "mark.wilkinson@upm.es",
        # "tests": [
        expect(set['identifier'].class).to eq String
        expect(set['title'].class).to eq String
        expect(set['description'].class).to eq String
        expect(set['creator'].class).to eq String
        expect(set['tests'].class).to eq Array
      end
    end
  end

  describe 'GET /champion/tests/' do
    it 'returns a list of known tests' do
      header 'accept', 'application/json'
      get '/champion/tests/'

      # puts "Status: #{last_response.status}"          # e.g., 200
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body).first
      json.keys.first do |_context|
        testt = json[testid]
        expect(testt['api'].class).to eq String
        expect(testt['title'].class).to eq String
        expect(testt['description'].class).to eq String
      end
    end
  end
end
