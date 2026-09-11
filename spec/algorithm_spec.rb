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
                       pass_weight: 5, error_weight: 0.0),
        hash_including(reference: 'T2', testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license',
                       fail_weight: -1, error_weight: 0.0)
      )
      expect(algo.conditions).to include(
        hash_including(condition: 'C1', formula: 'T1 > 0'),
        hash_including(condition: 'C2', formula: 'T1 + T2 == 10')
      )
    end
  end

  describe '#gather_metadata' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    before do
      stub_request(:post, 'https://tools.ostrails.eu/repositories/fdpindex-fdp')
        .to_return(
          status: 200,
          body: File.read('spec/support/fixtures/sample_sparql_response.json'),
          headers: { 'Content-Type' => 'application/sparql-results+json' }
        )
    end

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
      allow_any_instance_of(Champion::Core).to receive(:get_tests).and_return(
        [
          Champion::Test.new(
            identifier: 'some_test',
            title: 'Some Test',
            description: 'A test',
            endpoint: 'https://tests.ostrails.eu/assess/test/some_test/api'
          )
        ]
      )
      algo.load_configuration
      allow(algo).to receive(:parse_single_test_response).with(testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license').and_return('pass')
      allow(algo).to receive(:parse_single_test_response).with(testid: 'https://tests.ostrails.eu/tests/fc_metadata_authorization').and_return(nil) # removed and replaxced with mock output to fail this lookup
    end

    it 'processes test results with weights' do
      results = algo.process_resultset
      expect(results['T2']).to include(result: 'pass', weight: 5.0)
      expect(results['T1']).to include(result: 'indeterminate (result data not found)', weight: 0.0)
    end

    it 'applies error_weight (default 0.0 for legacy sheets) when a test result is "error"' do
      allow(algo).to receive(:parse_single_test_response)
        .with(testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license')
        .and_return('error')

      results = algo.process_resultset
      expect(results['T2']).to include(result: 'error', weight: 0.0)
    end
  end

  describe '#process_resultset with an Error Weight column' do
    let(:csv_response) { File.read('spec/support/fixtures/sample_csv_with_error_weight.csv') }
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }

    before do
      allow_any_instance_of(Champion::Core).to receive(:get_tests).and_return(
        [
          Champion::Test.new(
            identifier: 'some_test',
            title: 'Some Test',
            description: 'A test',
            endpoint: 'https://tests.ostrails.eu/assess/test/some_test/api'
          )
        ]
      )
      algo.load_configuration
      allow(algo).to receive(:parse_single_test_response)
        .with(testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license')
        .and_return('error')
      allow(algo).to receive(:parse_single_test_response)
        .with(testid: 'https://tests.ostrails.eu/tests/fc_metadata_authorization')
        .and_return(nil)
    end

    it 'reads the Error Weight column and uses it for "error" results' do
      expect(algo.tests).to include(hash_including(reference: 'T2', error_weight: -50.0))

      results = algo.process_resultset
      expect(results['T2']).to include(result: 'error', weight: -50.0)
    end
  end

  describe '#process' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }

    before do
      allow_any_instance_of(Champion::Core).to receive(:get_tests).and_return(
        [
          Champion::Test.new(
            identifier: 'some_test',
            title: 'Some Test',
            description: 'A test',
            endpoint: 'https://tests.ostrails.eu/assess/test/some_test/api'
          )
        ]
      )
      allow(algo).to receive(:evaluate_conditions).and_return([[], []])
      allow(algo).to receive(:extract_target_from_resultset).and_return('https://example.org/target/456')
    end

    it 'sets has_errors to true when a test result is "error"' do
      allow(algo).to receive(:process_resultset).and_return(
        'T1' => { log: 'ok', result: 'pass', weight: 5.0 },
        'T2' => { log: 'boom', result: 'error', weight: -50.0 }
      )
      expect(algo.process[:has_errors]).to be true
    end

    it 'sets has_errors to false when no test result is "error"' do
      allow(algo).to receive(:process_resultset).and_return(
        'T1' => { log: 'ok', result: 'pass', weight: 5.0 },
        'T2' => { log: 'ok', result: 'fail', weight: -1.0 }
      )
      expect(algo.process[:has_errors]).to be false
    end
  end

  describe 'input sanitization' do
    let(:dirty_csv) do
      <<~CSV
        Template Version 1.2,,,,
        ,,,,,
        DCAT Property,Value,Comment,,,
        title,Test Algorithm ,,,,
        isImplementationOf,https://example.org/benchmark ,,,,
        contactPoint,test@example.org,,,,
        ,,,,,
        Test Reference,Test GUID,Pass Weight,Fail Weight,Indeterminate Weight,
        T1 ,https://tests.ostrails.eu/tests/fc_metadata_authorization ,5,-100,0,
        T2 ,https://tests.ostrails.eu/tests/fc_metadata_includes_license ,5,-1,0,
        ,,,,,
        Condition,Description,Formula,Success Message,Fail Message,Guidance
        C1 ,Metadata available, T1 > 0 ,Pass ,Fail ,
      CSV
    end

    before do
      stub_request(:get, %r{https://docs\.google\.com/spreadsheets/d/.*})
        .to_return(status: 200, body: dirty_csv, headers: { 'Content-Type' => 'text/csv' })
      allow_any_instance_of(Champion::Core).to receive(:get_tests).and_return(
        [
          Champion::Test.new(
            identifier: 'some_test',
            title: 'Some Test',
            description: 'A test',
            endpoint: 'https://tests.ostrails.eu/assess/test/some_test/api'
          )
        ]
      )
    end

    it 'strips trailing spaces from Test GUID so the test appears in the ResultSet' do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid)
      algo.gather_metadata
      expect(algo.tests.map { |t| t[:testid] }).to all(satisfy { |id| id == id.strip })
      expect(algo.tests.first[:testid]).to eq('https://tests.ostrails.eu/tests/fc_metadata_authorization')
    end

    it 'strips trailing spaces from Test Reference' do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid)
      algo.gather_metadata
      expect(algo.tests.map { |t| t[:reference] }).to all(satisfy { |r| r == r.strip })
      expect(algo.tests.first[:reference]).to eq('T1')
    end

    it 'strips trailing spaces from condition fields' do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid)
      algo.load_configuration
      expect(algo.conditions.first[:condition]).to eq('C1')
      expect(algo.conditions.first[:formula]).to eq('T1 > 0')
    end

    it 'strips trailing spaces from metadata values' do
      algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid)
      algo.gather_metadata
      title_triple = algo.metadata.query([nil, RDF::Vocab::DC.title, nil]).first
      expect(title_triple.object.to_s).to eq('Test Algorithm')
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
