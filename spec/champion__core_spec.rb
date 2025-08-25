# spec/champion_core_spec.rb
require 'spec_helper'

RSpec.describe Champion::Core do
  let(:core) { described_class.new }
  let(:subject) { 'https://example.org/target/456' }
  let(:setid) { 'test_set' }
  let(:bmid) { 'https://example.org/benchmark/123' }

  describe '#get_test_endpoint_for_testid' do
    it 'fetches endpoint for a test ID', :vcr do
      stub_request(:get, 'https://tools.ostrails.eu/repositories/fdpindex-fdp')
        .to_return(
          status: 200,
          body: File.read('spec/support/fixtures/sample_sparql_response.rdf'),
          'SPARQL-Results': 'application/sparql-results+json'
        )
      endpoint = core.get_test_endpoint_for_testid(testid: 'https://tests.ostrails.eu/tests/test1')
      expect(endpoint).to eq('https://tests.ostrails.eu/assess/test/test1')
    end
  end

  describe '#run_test' do
    it 'executes a test and returns JSON result', :vcr do
      stub_request(:post, 'https://tests.ostrails.eu/assess/test/test1')
        .with(body: { 'resource_identifier' => subject }.to_json)
        .to_return(status: 200, body: { result: 'pass' }.to_json, headers: { 'Content-Type' => 'application/json' })
      result = core.run_test(testapi: 'https://tests.ostrails.eu/assess/test/test1', guid: subject)
      expect(result).to eq('result' => 'pass')
    end
  end
end