require 'spec_helper'

Champion::ChampionApp.set_routes if Champion::ChampionApp.routes['GET'].nil? || Champion::ChampionApp.routes['GET'].empty?

RSpec.describe 'Champion route branches' do
  include Rack::Test::Methods

  def app
    Champion::ChampionApp
  end

  let(:core) { double('Champion::Core') }
  let(:algorithm) { double('Algorithm') }
  let(:test_obj) do
    Champion::Test.new(
      identifier: 'test1',
      title: 'License Test',
      description: 'Checks license metadata',
      endpoint: 'https://tests.example/assess',
      openapi: 'https://tests.example/openapi',
      dimension: 'findable',
      objects: ['Dataset'],
      domain: ['Biology'],
      benchmark_or_metric: 'https://example.org/metric'
    )
  end

  let(:algorithm_result) do
    {
      metadata: RDF::Graph.new,
      testedguid: 'https://example.org/target',
      test_results: {},
      narratives: [],
      guidances: [],
      resultset: '{"@graph":[]}'
    }
  end

  before do
    allow(Champion::Core).to receive(:new).and_return(core)
    allow(core).to receive(:get_tests).and_return([test_obj])
    allow(core).to receive(:get_tests).with(testid: 'test1').and_return([test_obj])
    allow(core).to receive(:register_test).and_return('registered')
    allow(core).to receive(:add_test).and_return('test1')
    allow(core).to receive(:proxy_test).and_return('{"result":"pass"}')

    allow(Algorithm).to receive(:list).and_return([
                                                    {
                                                      identifier: 'https://tools.ostrails.eu/champion/algorithms/d/algo1',
                                                      title: 'Algorithm 1',
                                                      description: 'Scores metadata',
                                                      calculation_uri: 'https://docs.google.com/spreadsheets/d/algo1'
                                                    }
                                                  ])
    allow(Algorithm).to receive(:retrieve_by_id).and_return('https://docs.google.com/spreadsheets/d/algo1')
    allow(Algorithm).to receive(:generate_assess_algorithm_openapi).and_return({ openapi: '3.0.3' })
    allow(Algorithm).to receive(:new).and_return(algorithm)
    allow(algorithm).to receive(:register)
    allow(algorithm).to receive(:algorithm_guid).and_return('https://tools.ostrails.eu/champion/algorithms/d/algo1')
    metadata_graph = RDF::Graph.new
    metadata_graph << RDF::Statement.new(
      RDF::URI('https://tools.ostrails.eu/champion/algorithms/d/algo1'),
      RDF.type,
      RDF::URI('https://w3id.org/ftr#ScoringAlgorithm')
    )
    allow(algorithm).to receive(:gather_metadata).and_return(metadata_graph)
    allow(algorithm).to receive(:valid).and_return(true)
    allow(algorithm).to receive(:process).and_return(algorithm_result)
    allow_any_instance_of(Champion::ChampionApp).to receive(:sleep)

    parsed_result = Champion::TestResult.new(
      test_identifier: 'https://tests.example/test1',
      title: 'License Test',
      description: 'Checks license metadata',
      value: 'pass',
      log: 'SUCCESS',
      time: '2026-06-19T10:00:00Z',
      completion: '100',
      target_resource: 'https://example.org/target',
      rawjson: '{"result":"pass"}'
    )
    allow(Champion::TestResult).to receive(:test_output_parser).and_return(parsed_result)
  end

  describe 'basic redirects and pages' do
    it 'redirects root to /champion' do
      get '/'
      expect(last_response.status).to eq(307)
      expect(last_response.location).to end_with('/champion')
    end

    it 'redirects the API directory to the YAML spec' do
      get '/champion/api/'
      expect(last_response.status).to eq(307)
      expect(last_response.location).to end_with('/champion/championAPI.yaml')
    end

    it 'renders the homepage' do
      get '/champion/'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Execute a Benchmark Quality Assessment')
    end

    it 'redirects /champion/tests/new to the slash form' do
      get '/champion/tests/new'
      expect(last_response.status).to eq(307)
      expect(last_response.location).to end_with('/champion/tests/new/')
    end

    it 'renders the new-test form' do
      get '/champion/tests/new/'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'redirects /champion/tests to /champion/tests/' do
      get '/champion/tests'
      expect(last_response.status).to eq(301)
      expect(last_response.location).to end_with('/champion/tests/')
    end

    it 'returns JSON for missing API resources when JSON is requested' do
      get '/champion/missing-resource', {}, { 'HTTP_ACCEPT' => 'application/json' }

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include(
        'error' => 'The requested resource was not found: /champion/missing-resource',
        'status' => 404
      )
    end

    it 'returns JSON for missing API resources when JSON-LD is requested' do
      get '/champion/missing-resource', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include(
        'error' => 'The requested resource was not found: /champion/missing-resource',
        'status' => 404
      )
    end

    it 'returns HTML for missing browser resources when HTML is requested' do
      get '/champion/missing-resource', {}, { 'HTTP_ACCEPT' => 'text/html' }

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('The requested resource was not found: /champion/missing-resource')
    end
  end

  describe 'test list and registration branches' do
    it 'filters listed tests by keyword' do
      get '/champion/tests/', { keyword: 'license' }, { 'HTTP_ACCEPT' => 'application/json' }
      body = JSON.parse(last_response.body)
      expect(last_response.status).to eq(200)
      expect(body.first['identifier']).to eq('test1')
    end

    it 'rejects JSON-LD test list requests that the route cannot render' do
      get '/champion/tests/', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(406)
    end

    it 'registers a test from form params and renders HTML' do
      post '/champion/tests/new', { test_turtle: 'https://example.org/test.ttl' }, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('registered')
    end

    it 'registers a test from JSON and returns JSON' do
      post '/champion/tests/new',
           { test_turtle: 'https://example.org/test.ttl' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq('response' => 'registered')
    end

    it 'returns 406 for unsupported new-test response formats' do
      post '/champion/tests/new', { test_turtle: 'https://example.org/test.ttl' }, { 'HTTP_ACCEPT' => 'text/plain' }
      expect(last_response.status).to eq(406)
    end

    it 'redirects POST /champion/tests to /champion/tests/' do
      post '/champion/tests'
      expect(last_response.status).to eq(307)
      expect(last_response.location).to end_with('/champion/tests/')
    end

    it 'registers an OpenAPI test from JSON through /champion/tests/' do
      post '/champion/tests/',
           { openapi: 'https://example.org/openapi.yaml' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
    end

    it 'registers an OpenAPI test from form params and renders HTML' do
      post '/champion/tests/',
           { openapi: 'https://example.org/openapi.yaml' },
           { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'returns 406 for unsupported test registration response formats' do
      post '/champion/tests/',
           { openapi: 'https://example.org/openapi.yaml' },
           { 'HTTP_ACCEPT' => 'text/plain' }
      expect(last_response.status).to eq(406)
    end
  end

  describe 'test execution proxy branches' do
    it 'runs harvest-only proxy for JSON input' do
      post '/champion/harvest_only',
           { resource_identifier: ' https://example.org/target ' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('{"result":"pass"}')
      expect(core).to have_received(:proxy_test).with(
        endpoint: 'https://tests.ostrails.eu/tests/assess/test/fc_harvest_only',
        resource_identifier: 'https://example.org/target'
      )
    end

    it 'rejects harvest-only non-JSON input' do
      post '/champion/harvest_only', resource_identifier: 'https://example.org/target'
      expect(last_response.status).to eq(406)
    end

    it 'rejects harvest-only JSON without a resource identifier' do
      post '/champion/harvest_only',
           { other: 'value' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(406)
    end

    it 'rejects harvest-only malformed JSON' do
      post '/champion/harvest_only',
           '{',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Invalid JSON body')
    end

    it 'rejects harvest-only blank resource identifiers' do
      post '/champion/harvest_only',
           { resource_identifier: '  ' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'Missing resource_identifier')
    end

    it 'rejects test-execution proxy without endpoint' do
      post '/champion/test-execution-proxy', resource_identifier: 'https://example.org/target'
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'Missing endpoint')
    end

    it 'runs test-execution proxy for resource identifiers and returns JSON' do
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', resource_identifier: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('{"result":"pass"}')
    end

    it 'renders test-execution proxy results as HTML' do
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', resource_identifier: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('FAIR Test Execution Visualization')
    end

    it 'returns 406 for unsupported test-execution proxy response formats' do
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', resource_identifier: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'text/plain' }
      expect(last_response.status).to eq(406)
    end

    it 'returns parser failures as JSON errors' do
      allow(Champion::TestResult).to receive(:test_output_parser).and_return('not a parsed result')
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', resource_identifier: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)).to include('error')
    end

    it 'forwards uploaded metadata files as multipart requests' do
      response = double('RestClient::Response', body: '{"result":"pass"}', code: 202)
      allow(RestClient).to receive(:post).and_return(response)
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/sample_resultset.jsonld', 'application/json')

      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file', metadata_file: upload },
           { 'HTTP_ACCEPT' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer token' }

      expect(last_response.status).to eq(202)
      expect(RestClient).to have_received(:post)
    end

    it 'rejects metadata-file mode without a file' do
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'No metadata file uploaded')
    end

    it 'rejects metadata uploads that are not JSON files' do
      upload = Rack::Test::UploadedFile.new('complete_coverage.txt', 'text/plain')
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file', metadata_file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'File should be a JSON file (e.g. ro-crate-metadata.json)')
    end

    it 'rejects metadata uploads containing malformed JSON' do
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/invalid.json', 'application/json')
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file', metadata_file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'Uploaded file is not valid JSON')
    end

    it 'passes through remote API error responses for metadata uploads' do
      response = double('RestClient::Response', body: '{"error":"remote"}')
      exception = RestClient::ExceptionWithResponse.new(response)
      allow(exception).to receive(:http_code).and_return(502)
      allow(RestClient).to receive(:post).and_raise(exception)
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/sample_resultset.jsonld', 'application/json')

      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file', metadata_file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }

      expect(last_response.status).to eq(502)
      expect(last_response.body).to eq('{"error":"remote"}')
    end

    it 'returns 500 when metadata upload forwarding raises unexpectedly' do
      allow(RestClient).to receive(:post).and_raise(StandardError, 'network unavailable')
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/sample_resultset.jsonld', 'application/json')

      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', submission_mode: 'metadata_file', metadata_file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }

      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)).to include('error' => 'Failed to submit to remote API: network unavailable')
    end

    it 'rejects GUID proxy submissions with blank resource identifiers' do
      post '/champion/test-execution-proxy',
           { endpoint: 'https://tests.example/assess', resource_identifier: ' ' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => 'Missing resource_identifier')
    end
  end

  describe 'algorithm routes' do
    it 'renders the algorithm registration form' do
      get '/champion/algorithms/new'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Register Benchmark Assessment Algorithm')
    end

    it 'rejects invalid algorithm registration URIs' do
      post '/champion/algorithms/new', calculation_uri: 'https://example.org/not-a-sheet'
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Invalid calculation URI')
    end

    it 'registers a valid algorithm and redirects to display' do
      post '/champion/algorithms/new', calculation_uri: 'https://docs.google.com/spreadsheets/d/algo1'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/champion/algorithms/d/algo1/display')
    end

    it 'renders a registered algorithm display page' do
      get '/champion/algorithms/d/algo1/display'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'renders the algorithms list as HTML' do
      get '/champion/algorithms/', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'returns algorithm metadata as JSON-LD' do
      get '/champion/algorithms/d/algo1', {}, { 'HTTP_ACCEPT' => 'application/ld+json' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('ScoringAlgorithm')
    end

    it 'returns algorithm metadata as JSON' do
      get '/champion/algorithms/d/algo1', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('ScoringAlgorithm')
    end

    it 'renders the algorithm assessment form' do
      get '/champion/assess/algorithms/new'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Algorithm Configuration Google Spreadsheet URL')
    end

    it 'rewrites form assessment submissions to the algorithm endpoint' do
      post '/champion/assess/algorithm',
           { calculation_uri: 'https://docs.google.com/spreadsheets/d/algo1', guid: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('resultset')
    end

    it 'rewrites JSON assessment submissions to the algorithm endpoint' do
      post '/champion/assess/algorithm',
           { calculation_uri: 'https://docs.google.com/spreadsheets/d/algo1', guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('resultset')
    end

    it 'rejects JSON assessment rewrites without calculation_uri' do
      post '/champion/assess/algorithm',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(406)
    end

    it 'rejects malformed JSON assessment rewrites' do
      post '/champion/assess/algorithm',
           '{',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Invalid JSON body before rewrite')
    end

    it 'rejects assessment rewrites without calculation_uri params' do
      post '/champion/assess/algorithm',
           { guid: 'https://example.org/target' },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(406)
    end

    it 'returns generated assessment OpenAPI as JSON' do
      get '/champion/assess/algorithm/d/algo1', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq('openapi' => '3.0.3')
    end

    it 'currently serves trailing slash assessment OpenAPI URLs through the broader GET route' do
      get '/champion/assess/algorithm/d/algo1/'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq('openapi' => '3.0.3')
    end

    it 'redirects trailing slash assessment OpenAPI URLs when JSON is not accepted' do
      get '/champion/assess/algorithm/d/algo1/', {}, { 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(301)
      expect(last_response.location).to end_with('/champion/assess/algorithm/d/algo1')
    end

    it 'rejects unknown registered algorithms' do
      allow(Algorithm).to receive(:retrieve_by_id).and_return(false)
      post '/champion/assess/algorithm/d/missing',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(404)
    end

    it 'rejects invalid algorithm payload JSON' do
      post '/champion/assess/algorithm/d/algo1',
           '{',
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Invalid JSON algo post')
    end

    it 'treats JSON bodies without guid or resultset as direct resultsets' do
      post '/champion/assess/algorithm/d/algo1',
           [].to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('resultset')
      expect(Algorithm).to have_received(:new).with(
        calculation_uri: 'https://docs.google.com/spreadsheets/d/algo1',
        guid: nil,
        resultset: []
      )
    end

    it 'renders algorithm assessment results as HTML' do
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'text/html' }
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'returns algorithm assessment resultsets for text/turtle requests' do
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'text/turtle' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('{"@graph":[]}')
    end

    it 'returns 406 for unsupported algorithm assessment response formats' do
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'text/plain' }
      expect(last_response.status).to eq(406)
    end

    it 'accepts uploaded resultsets for form algorithm assessments' do
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/sample_resultset.jsonld', 'application/json')
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target', file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('resultset')
    end

    it 'rejects malformed uploaded resultsets for form algorithm assessments' do
      upload = Rack::Test::UploadedFile.new('spec/support/fixtures/invalid.json', 'application/json')
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target', file: upload },
           { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Invalid JSON file upload')
    end

    it 'rejects invalid algorithm objects' do
      allow(algorithm).to receive(:valid).and_return(false)
      post '/champion/assess/algorithm/d/algo1',
           { guid: 'https://example.org/target' }.to_json,
           { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(406)
    end

    it 'returns 406 when fetching an unknown algorithm display page' do
      allow(Algorithm).to receive(:retrieve_by_id).and_return(false)
      get '/champion/algorithms/d/missing/display'
      expect(last_response.status).to eq(406)
      expect(last_response.body).to include('unable to find that algorithm')
    end
  end
end
