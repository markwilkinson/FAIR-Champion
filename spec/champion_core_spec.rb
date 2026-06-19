# spec/champion_core_spec.rb
require 'spec_helper'

RSpec.describe Champion::Core do
  let(:core) { described_class.new }
  let(:subject) { 'https://example.org/target/456' }
  let(:setid) { 'test_set' }
  let(:bmid) { 'https://example.org/benchmark/123' }
  let(:sparql_client) { instance_double('SPARQL::Client') }

  def solution(bindings)
    bindings.transform_values! do |value|
      value.respond_to?(:value) ? value : double('RDF value', value: value, to_s: value.to_s)
    end
  end

  describe '#run_benchmark_assessment' do
    it 'loads a benchmark, resolves metric endpoints, and executes them' do
      repository = instance_double('RDF::Repository')
      metric_solution = { metric: double('Metric URI', value: 'https://example.org/metric') }
      allow(RDF::Repository).to receive(:load).with(bmid).and_return(repository)
      allow(SPARQL).to receive(:execute).and_return([metric_solution])
      allow(core).to receive(:get_test_endpoints_for_metric)
        .with(metric: 'https://example.org/metric')
        .and_return([
                      ['https://tests.example/test1', 'https://tests.example/test1/api'],
                      ['https://tests.example/test2', 'https://tests.example/test2/api']
                    ])
      allow(core).to receive(:execute_on_endpoints).and_return('jsonld')

      expect(core.run_benchmark_assessment(subject: subject, bmid: bmid)).to eq('jsonld')
      expect(core).to have_received(:execute_on_endpoints).with(
        subject: subject,
        endpoints: ['https://tests.example/test1/api', 'https://tests.example/test2/api'],
        bmid: bmid
      )
    end
  end

  describe '#get_test_endpoints_for_metric' do
    it 'queries the FDP index for test endpoint pairs' do
      allow(SPARQL::Client).to receive(:new).and_return(sparql_client)
      allow(sparql_client).to receive(:query).and_return([
                                                           solution(
                                                             testid: 'https://tests.example/test1',
                                                             endpoint: 'https://tests.example/test1/api'
                                                           )
                                                         ])

      expect(core.get_test_endpoints_for_metric(metric: ' https://example.org/metric ')).to eq(
        [['https://tests.example/test1', 'https://tests.example/test1/api']]
      )
      expect(SPARQL::Client).to have_received(:new).with(Configuration.fdpindex_sparql)
      expect(sparql_client).to have_received(:query).with(include('<https://example.org/metric>'))
    end
  end

  describe '#get_test_endpoint_for_testid' do
    it 'fetches endpoint for a test ID', :vcr do
      stub_request(:post, 'https://tools.ostrails.eu/repositories/fdpindex-fdp')
        .to_return(
          status: 200,
          body: File.read('spec/support/fixtures/sample_sparql_response.json'),
          headers: { 'Content-Type' => 'application/sparql-results+json' }
        )
      endpoint = core.get_test_endpoint_for_testid(testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license')
      expect(endpoint).to eq('https://tests.ostrails.eu/assess/test/fc_metadata_includes_license')
    end
  end

  describe '#execute_on_endpoints' do
    let(:output) { instance_double('Champion::Output') }

    before do
      allow(Champion::Output).to receive(:new).and_return(output)
      allow(output).to receive(:build_output).and_return('jsonld')
    end

    it 'runs each endpoint and builds a combined output document' do
      endpoints = [
        { testid: 'test1', endpoint: 'https://tests.example/test1/api' },
        { testid: 'test2', endpoint: 'https://tests.example/test2/api' }
      ]
      allow(core).to receive(:run_test).with(guid: subject, testapi: 'https://tests.example/test1/api',
                                             testid: 'test1').and_return('id' => 'result1')
      allow(core).to receive(:run_test).with(guid: subject, testapi: 'https://tests.example/test2/api',
                                             testid: 'test2').and_return('id' => 'result2')

      expect(core.execute_on_endpoints(subject: subject, endpoints: endpoints, bmid: bmid)).to eq('jsonld')
      expect(output).to have_received(:build_output) do |args|
        expect(args[:results]).to contain_exactly({ 'id' => 'result1' }, { 'id' => 'result2' })
      end
    end

    it 'adds an indeterminate result when an endpoint thread fails' do
      endpoints = [{ testid: 'test1', endpoint: 'https://tests.example/test1/api' }]
      allow(core).to receive(:run_test).and_raise(StandardError, 'boom')

      expect(core.execute_on_endpoints(subject: subject, endpoints: endpoints, bmid: bmid)).to eq('jsonld')
      expect(output).to have_received(:build_output) do |args|
        result = args[:results].first
        expect(result).to include(
          '@type' => 'ftr:TestResult',
          'status' => 'indeterminate',
          'outputFromTest' => 'test1'
        )
        expect(result['log']).to include('boom')
      end
    end
  end

  describe '#run_test' do
    it 'executes a test and returns JSON result', :vcr do
      stub_request(:post, 'https://tests.ostrails.eu/assess/test/fc_metadata_includes_license')
        .with(body: { 'resource_identifier' => subject }.to_json)
        .to_return(status: 200, body: { result: 'pass' }.to_json, headers: { 'Content-Type' => 'application/json' })
      result = core.run_test(
        testapi: 'https://tests.ostrails.eu/assess/test/fc_metadata_includes_license',
        guid: subject,
        testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license'
      )
      expect(result).to eq('result' => 'pass')
    end

    it 'returns an error document when the test API responds with an error' do
      response = double('RestClient::Response', code: 500, body: '{"error":"bad"}')
      exception = RestClient::ExceptionWithResponse.new(response)
      allow(RestClient::Request).to receive(:execute).and_raise(exception)

      result = core.run_test(
        testapi: 'https://tests.example/fail',
        guid: subject,
        testid: 'test1'
      )

      expect(result['error']).to include('https://tests.example/fail did not respond happily')
    end

    it 'returns an error document when test execution raises unexpectedly' do
      allow(RestClient::Request).to receive(:execute).and_raise(StandardError, 'network unavailable')

      result = core.run_test(
        testapi: 'https://tests.example/error',
        guid: subject,
        testid: 'test1'
      )

      expect(result['error']).to include('network unavailable')
    end
  end

  describe '#get_tests' do
    before do
      allow(SPARQL::Client).to receive(:new).and_return(sparql_client)
    end

    it 'aggregates multi-valued test metadata into Champion::Test objects' do
      allow(sparql_client).to receive(:query).and_return([
                                                           solution(
                                                             identifier: 'https://tests.example/test1',
                                                             title: 'Test One',
                                                             description: 'Checks a thing',
                                                             endpoint: 'https://tests.example/test1/api',
                                                             openapi: 'https://tests.example/test1/openapi',
                                                             dimension: 'findable',
                                                             objects: 'Dataset',
                                                             domain: 'Biology',
                                                             benchmark_or_metric: 'https://example.org/metric'
                                                           ),
                                                           solution(
                                                             identifier: 'https://tests.example/test1',
                                                             title: 'Ignored duplicate title',
                                                             description: 'Ignored duplicate description',
                                                             endpoint: 'https://tests.example/test1/api',
                                                             openapi: 'https://tests.example/test1/openapi',
                                                             dimension: 'findable',
                                                             objects: 'Software',
                                                             domain: 'Chemistry',
                                                             benchmark_or_metric: 'https://example.org/metric'
                                                           )
                                                         ])

      tests = core.get_tests

      expect(tests.length).to eq(1)
      expect(tests.first).to have_attributes(
        identifier: 'https://tests.example/test1',
        title: 'Test One',
        description: 'Checks a thing',
        endpoint: 'https://tests.example/test1/api',
        openapi: 'https://tests.example/test1/openapi',
        dimension: 'findable',
        benchmark_or_metric: 'https://example.org/metric'
      )
      expect(tests.first.objects).to eq(%w[Dataset Software])
      expect(tests.first.domain).to eq(%w[Biology Chemistry])
    end

    it 'filters tests by the local identifier when a full test URI is provided' do
      allow(sparql_client).to receive(:query).and_return([
                                                           solution(
                                                             identifier: 'https://tests.example/test1',
                                                             title: 'Test One',
                                                             description: 'One'
                                                           ),
                                                           solution(
                                                             identifier: 'https://tests.example/test2',
                                                             title: 'Test Two',
                                                             description: 'Two'
                                                           )
                                                         ])

      tests = core.get_tests(testid: 'https://tests.example/test2')

      expect(tests.map(&:identifier)).to eq(['https://tests.example/test2'])
    end
  end

  describe '#proxy_test' do
    it 'posts a stripped resource identifier and returns the response body' do
      response = double('RestClient::Response', code: 200, body: '{"result":"pass"}')
      allow(RestClient).to receive(:post).and_return(response)

      expect(core.proxy_test(endpoint: 'https://tests.example/proxy', resource_identifier: " #{subject} ")).to eq(
        '{"result":"pass"}'
      )
      expect(RestClient).to have_received(:post).with(
        'https://tests.example/proxy',
        { resource_identifier: subject }.to_json,
        { content_type: :json, accept: :json }
      )
    end

    it 'returns the response body when the proxied test API responds with an error' do
      response = double('RestClient::Response', code: 500, body: '{"error":"bad"}')
      exception = RestClient::ExceptionWithResponse.new(response)
      allow(RestClient).to receive(:post).and_raise(exception)

      expect(core.proxy_test(endpoint: 'https://tests.example/proxy', resource_identifier: subject)).to eq(
        '{"error":"bad"}'
      )
    end

    it 'returns a JSON error body when proxying raises unexpectedly' do
      allow(RestClient).to receive(:post).and_raise(StandardError, 'network unavailable')

      result = JSON.parse(core.proxy_test(endpoint: 'https://tests.example/proxy', resource_identifier: subject))

      expect(result['error']).to include('network unavailable')
    end
  end

  describe '#register_test' do
    it 'registers a test through the configured FDP index proxy' do
      response = double('RestClient::Response', body: '{"ok":true}')
      allow(RestClient::Request).to receive(:execute).and_return(response)

      expect(core.register_test(test_turtle: 'https://example.org/test.ttl')).to eq(response)
      expect(RestClient::Request).to have_received(:execute).with(
        method: :post,
        url: Configuration.fdp_index_proxy,
        payload: { 'clientUrl' => 'https://example.org/test.ttl' }.to_json,
        headers: { accept: 'application/json', content_type: 'application/json' },
        max_redirects: 10
      )
    end

    it 'returns a useful message when registration receives an API error' do
      response = double('RestClient::Response', code: 422, body: '{"error":"bad turtle"}')
      exception = RestClient::ExceptionWithResponse.new(response)
      allow(RestClient::Request).to receive(:execute).and_raise(exception)

      expect(core.register_test(test_turtle: 'https://example.org/test.ttl')).to include(
        'Test Registration failed'
      )
    end

    it 'returns a useful message when registration raises unexpectedly' do
      allow(RestClient::Request).to receive(:execute).and_raise(StandardError, 'network unavailable')

      expect(core.register_test(test_turtle: 'https://example.org/test.ttl')).to include(
        'network unavailable'
      )
    end
  end
end
