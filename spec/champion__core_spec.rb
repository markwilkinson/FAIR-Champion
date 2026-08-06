# spec/champion_core_spec.rb
require 'spec_helper'

RSpec.describe Champion::Core do
  let(:core) { described_class.new }
  let(:subject) { 'https://example.org/target/456' }
  let(:setid) { 'test_set' }
  let(:bmid) { 'https://example.org/benchmark/123' }

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
  end

  describe '#execute_on_endpoints' do
    it 'caps concurrency per host while still running different hosts in parallel' do
      endpoints = (1..5).map { |i| { testid: "a#{i}", endpoint: "https://host-a.example/#{i}" } } +
                  [{ testid: 'b1', endpoint: 'https://host-b.example/1' }]

      in_flight = Hash.new(0)
      max_in_flight = Hash.new(0)
      mutex = Mutex.new

      allow(core).to receive(:run_test) do |**kwargs|
        host = URI(kwargs[:testapi]).host
        mutex.synchronize do
          in_flight[host] += 1
          max_in_flight[host] = [max_in_flight[host], in_flight[host]].max
        end
        sleep 0.05
        mutex.synchronize { in_flight[host] -= 1 }
        { 'status' => 'pass' }
      end

      stub_const('Champion::Core::PER_HOST_TEST_CONCURRENCY', 3)

      result = core.execute_on_endpoints(subject: subject, endpoints: endpoints, bmid: bmid)

      expect(max_in_flight['host-a.example']).to eq(3) # 5 tests, capped at 3
      expect(max_in_flight['host-b.example']).to eq(1) # only 1 test on this host
      expect(result).to be_a(String)
    end
  end
end