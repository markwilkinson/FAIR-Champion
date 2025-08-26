# spec/routes_content_spec.rb
require_relative 'spec_helper'

# Ensure routes are registered once
Champion::ChampionApp.set_routes
puts "Registered GET routes: #{Champion::ChampionApp.routes['GET']&.map { |r| r[0].to_s }&.inspect || 'No GET routes'}"

# RSpec tests for Sinatra routes in routes.rb, focusing on content type negotiation.
# Assumes routes.rb is in lib/ and defines routes in Champion::ChampionApp.
RSpec.describe 'Champion Routes' do
  include Rack::Test::Methods

  def app
    Champion::ChampionApp
  end

  # Mock Champion::Core for test-related routes
  before do
    core_instance = instance_double('Champion::Core')
    allow(Champion::Core).to receive(:new).and_return(core_instance)
    allow(core_instance).to receive(:get_tests).with(no_args).and_return(
      [{ identifier: 'test1', title: 'Test 1', description: 'A test' }]
    )
    allow(core_instance).to receive(:get_tests).with(hash_including(testid: 'test1')).and_return(
      [{ identifier: 'test1', title: 'Test 1', description: 'A test' }]
    )
  end

  # Mock Algorithm class for algorithm-related routes
  before do
    allow(Algorithm).to receive(:list).and_return(
      { 'algo1' => ['Algorithm 1', 'Scoring Function'] }
    )
    allow(Algorithm).to receive(:retrieve_by_id).with(algorithm_id: 'algo1').and_return('https://docs.google.com/spreadsheets/d/algo1')
    allow(Algorithm).to receive(:generate_assess_algorithm_openapi).with(algorithmid: 'algo1').and_return({ openapi: '3.0.0' })
    allow(Algorithm).to receive(:new).and_return(algorithm_mock)
    allow(algorithm_mock).to receive(:register)
    allow(algorithm_mock).to receive(:algorithm_guid).and_return('algo1')
    allow(algorithm_mock).to receive(:gather_metadata).and_return(RDF::Graph.new)
    allow(algorithm_mock).to receive(:valid).and_return(true)
    allow(algorithm_mock).to receive(:process).and_return({ resultset: '{}' })
  end
  let(:algorithm_mock) { instance_double('Algorithm') }

  describe 'GET /test' do
    it 'returns 200' do
      get '/test'
      puts "Test route status: #{last_response.status}, Body: #{last_response.body}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('Test route works')
    end
  end

  describe 'GET /champion/tests/' do
    describe 'Debug GET /champion/tests/' do
      it 'checks response' do
        get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'text/html' }
        puts "Status: #{last_response.status}, Body: #{last_response.body}"
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to match(%r{text/html})
      end
    end

    it 'returns HTML for text/html' do
      get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/html})
    end

    it 'returns JSON for application/json' do
      get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/ld+json' do
      get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/json with quality score' do
      get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'application/json;q=0.9' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end
  end

  describe 'GET /champion/tests/:testid' do
    it 'returns HTML for text/html' do
      get '/champion/tests/test1', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/html})
    end

    it 'returns JSON for application/json' do
      get '/champion/tests/test1', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/ld+json' do
      get '/champion/tests/test1', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/json with quality score' do
      get '/champion/tests/test1', {}, { 'HTTP_ACCEPT' => 'application/json;q=0.8' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end
  end

  describe 'GET /champion/algorithms/' do
    it 'returns HTML for text/html' do
      get '/champion/algorithms/', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/html})
    end

    it 'returns JSON for application/json' do
      get '/champion/algorithms/', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/ld+json' do
      get '/champion/algorithms/', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/json with quality score' do
      get '/champion/algorithms/', {}, { 'HTTP_ACCEPT' => 'application/json;q=0.9' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end
  end

  describe 'GET /champion/algorithms/:algorithmid' do
    it 'returns HTML for text/html' do
      get '/champion/algorithms/algo1', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/html})
    end

    it 'returns Turtle for application/json due to workaround' do
      get '/champion/algorithms/algo1', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/turtle})
    end

    it 'returns Turtle for application/ld+json due to workaround' do
      get '/champion/algorithms/algo1', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/turtle})
    end

    it 'returns Turtle for text/turtle' do
      get '/champion/algorithms/algo1', {}, { 'HTTP_ACCEPT' => 'text/turtle' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/turtle})
    end

    it 'returns Turtle for application/json with quality score' do
      get '/champion/algorithms/algo1', {}, { 'HTTP_ACCEPT' => 'application/json;q=0.8' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/turtle})
    end
  end

  describe 'POST /champion/assess/algorithm/:algorithmid' do
    let(:payload) { { guid: 'https://example.org/target/456' }.to_json }

    it 'returns HTML for text/html' do
      post '/champion/assess/algorithm/algo1', payload, { 'HTTP_ACCEPT' => 'text/html', 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/html})
    end

    it 'returns JSON for application/json' do
      post '/champion/assess/algorithm/algo1', payload, { 'HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/ld+json' do
      post '/champion/assess/algorithm/algo1', payload, { 'HTTP_ACCEPT' => 'application/ld+json', 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON for application/json with quality score' do
      post '/champion/assess/algorithm/algo1', payload, { 'HTTP_ACCEPT' => 'application/json;q=0.9', 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{application/json})
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns JSON-LD string for text/turtle' do
      post '/champion/assess/algorithm/algo1', payload, { 'HTTP_ACCEPT' => 'text/turtle', 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match(%r{text/turtle})
    end
  end
end