# spec/algorithm_spec.rb
require 'spec_helper'

RSpec.describe Algorithm do
  let(:calculation_uri) { 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w' }
  let(:base_uri) { 'https://tools.ostrails.eu/champion' }
  let(:guid) { 'https://example.org/target/456' }
  let(:resultset) { File.read('spec/support/fixtures/sample_resultset.jsonld') }
  let(:csv_response) { File.read('spec/support/fixtures/sample_csv.csv') }

  before do
    stub_request(:get, %r{https://docs\.google\.com/spreadsheets/d/.*})
      .to_return(status: 200, body: csv_response, headers: { 'Content-Type' => 'text/csv' })
  end

  describe '#initialize' do
    it 'sets up the algorithm with valid inputs', :vcr do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid)
      expect(algo.valid).to be true
      expect(algo.algorithm_id).to eq('16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w')
      expect(algo.algorithm_guid).to eq("#{base_uri}/algorithms/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w")
      expect(algo.csv).to be_an(Array)
    end

    it 'is invalid without guid or resultset' do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri)
      expect(algo.valid).to be false
    end
  end

  describe '#load_configuration' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'parses CSV into tests and conditions', :vcr do
      algo.load_configuration
      expect(algo.tests).to include(
        hash_including(reference: 'T1', testid: 'https://tests.ostrails.eu/tests/test1', pass_weight: 1.0),
        hash_including(reference: 'T2', testid: 'https://tests.ostrails.eu/tests/test2', pass_weight: 2.0)
      )
      expect(algo.conditions).to include(
        hash_including(condition: 'C1', formula: 'T1 + T2 > 1.0')
      )
    end
  end

  describe '#gather_metadata' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'builds RDF metadata graph', :vcr do
      algo.gather_metadata
      expect(algo.metadata).to be_an(RDF::Graph)
      expect(algo.metadata.query([nil, RDF::Vocab::DC.title, RDF::Literal.new('Sample Algorithm')]).count).to eq(1)
      expect(algo.benchmarkguid).to eq('https://example.org/benchmark/123')
    end
  end

  describe '#process_resultset' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }

    before do
      algo.load_configuration
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'https://tests.ostrails.eu	tests/test1').and_return('pass')
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'https://tests.ostrails.eu/tests/test2').and_return(nil)
    end

    it 'processes test results with weights', :vcr do
      results = algo.process_resultset
      expect(results['T1']).to include(result: 'pass', weight: 1.0)
      expect(results['T2']).to include(result: 'indeterminate (result data not found)', weight: 0.0)
    end
  end

  describe '#evaluate_conditions' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }
    let(:test_results) do
      {
        'T1' => { result: 'pass', weight: 1.0 },
        'T2' => { result: 'pass', weight: 2.0 }
      }
    end

    before { algo.load_configuration }

    it 'evaluates conditions and generates narratives', :vcr do
      narratives = algo.evaluate_conditions(test_results)
      expect(narratives).to include('All tests passed;')
    end
  end
end