# spec/algorithm_spec.rb
require 'spec_helper'
require 'stringio'

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
      expect(algo.algorithm_id).to eq('d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w')
      expect(algo.algorithm_guid).to eq("#{base_uri}/algorithms/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w")
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
      # Capture stderr output
      captured_warnings = StringIO.new
      original_stderr = $stderr
      $stderr = captured_warnings

      begin
        algo.load_configuration
        # Print captured warnings for debugging
        unless captured_warnings.string.empty?
          puts "Captured warnings from load_configuration:\n#{captured_warnings.string}"
        end
      ensure
        # Restore original stderr to avoid affecting other tests
        $stderr = original_stderr
      end

      # Your existing assertions
      expect(algo.tests).to include(
        hash_including(reference: 'T1', testid: 'https://tests.ostrails.eu/tests/fc_metadata_authorization',
                       pass_weight: 5),
        hash_including(reference: 'T2', testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license',
                       fail_weight: -1)
      )
      expect(algo.conditions).to include(
        hash_including(condition: 'C1', formula: 'T1 > 0'),
        hash_including(condition: 'C2', formula: 'T1 + T2 == 10')
      )
    end
  end

  describe '#gather_metadata' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'builds RDF metadata graph', :vcr do
      algo.gather_metadata
      expect(algo.metadata).to be_an(RDF::Graph)
      expect(algo.metadata.query([nil, RDF::Vocab::DC.title,
                                  RDF::Literal.new('Demonstration Algorithm')]).count).to eq(1)
      expect(algo.benchmarkguid).to eq('https://ostrails.github.io/sandbox/mockbenchmark1.ttl')
    end
  end

  describe '#process_resultset' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }

    before do
      algo.load_configuration
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license').and_return('pass')
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'https://tests.ostrails.eu/tests/fc_metadata_authorization').and_return(nil) # removed and replaxced with mock output to fail this lookup
    end

    it 'processes test results with weights', :vcr do
      results = algo.process_resultset
      expect(results['T2']).to include(result: 'pass', weight: 5.0)
      expect(results['T1']).to include(result: 'indeterminate (result data not found)', weight: 0.0)
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
      warn "\n\n\nnarratives #{narratives}\n\n\n"
      expect(narratives.first).to include('Acceptable: metadata passes authorization test')
    end
  end
end
