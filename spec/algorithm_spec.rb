# spec/algorithm_spec.rb
require 'spec_helper'
require 'stringio'

RSpec.describe Algorithm do
  let(:calculation_uri) { 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w' }
  let(:base_uri) { 'https://tools.ostrails.eu/champion' }
  let(:guid) { 'https://example.org/target/456' }
  let(:resultset) { File.read('spec/support/fixtures/sample_resultset.jsonld') }
  let(:resultset_with_target_identifier) do
    {
      '@context' => {
        'prov' => 'http://www.w3.org/ns/prov#',
        'dct' => 'http://purl.org/dc/terms/',
        'ftr' => 'https://w3id.org/ftr#'
      },
      '@graph' => [
        {
          '@id' => 'urn:activity',
          '@type' => 'ftr:TestExecutionActivity',
          'prov:used' => { '@id' => 'https://example.org/target' }
        },
        {
          '@id' => 'https://example.org/target',
          'dct:identifier' => 'https://example.org/target'
        }
      ]
    }.to_json
  end
  let(:csv_response) { File.read('spec/support/fixtures/sample_csv.csv') }

  before do
    stub_request(:get, %r{https://docs\.google\.com/spreadsheets/d/.*})
      .to_return(status: 200, body: csv_response, headers: { 'Content-Type' => 'text/csv' })
    allow_any_instance_of(Champion::Core).to receive(:get_test_endpoint_for_testid)
      .and_return('https://tests.ostrails.eu/assess/test/some_test/api')
  end

  describe 'JSON generator compatibility patch' do
    it 'supports except on JSON generator state objects' do
      state = JSON::Ext::Generator::State.new
      expect(state.except(:max_nesting)).not_to include(:max_nesting)
    end
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

  describe 'invalid CSV structure' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    before { algo.csv = ["Template Version 1.2\n", "DCAT Property,Value\n", "title,Broken\n"] }

    it 'rejects metadata without enough block separators' do
      expect { algo.gather_metadata }.to raise_error(RuntimeError, /Invalid CSV structure/)
    end

    it 'rejects configuration without enough block separators' do
      allow(algo).to receive(:gather_metadata)
      expect { algo.load_configuration }.to raise_error(RuntimeError, /Invalid CSV structure/)
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

  describe '#process' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'loads configuration, runs tests, parses the resultset, and returns a complete result hash' do
      test_results = { 'T1' => { result: 'pass', weight: 5.0 } }
      allow(algo).to receive(:load_configuration)
      allow(algo).to receive(:run_tests) { algo.resultset = resultset }
      allow(algo).to receive(:extract_target_from_resultset).and_return('https://w3id.org/duchenne-fdp')
      allow(algo).to receive(:process_resultset).and_return(test_results)
      allow(algo).to receive(:evaluate_conditions).with(test_results).and_return([['ok'], [[]]])

      output = algo.process

      expect(algo.resultsetgraph).not_to be_empty
      expect(output).to include(
        metadata: algo.metadata,
        test_results: test_results,
        narratives: ['ok'],
        resultset: resultset,
        testedguid: 'https://w3id.org/duchenne-fdp',
        guidances: [[]]
      )
    end

    it 'continues when a supplied resultset cannot be parsed into RDF' do
      algo.resultset = '{not json'
      allow(algo).to receive(:load_configuration)
      allow(algo).to receive(:extract_target_from_resultset).and_return('unknown-target')
      allow(algo).to receive(:process_resultset).and_return({})
      allow(algo).to receive(:evaluate_conditions).and_return([[], []])

      expect(algo.process).to include(testedguid: 'unknown-target')
    end
  end

  describe '#run_tests' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }
    let(:core) { instance_double('Champion::Core') }

    before do
      algo.tests = [
        { testid: 'https://tests.example/one', endpoint: 'https://tests.example/one/api' },
        { testid: 'https://tests.example/two', endpoint: 'https://tests.example/two/api' }
      ]
      algo.benchmarkguid = 'https://example.org/benchmark'
      allow(Champion::Core).to receive(:new).and_return(core)
      allow(core).to receive(:execute_on_endpoints).and_return(resultset)
    end

    it 'delegates endpoint execution to Champion::Core and stores the returned resultset' do
      algo.run_tests

      expect(core).to have_received(:execute_on_endpoints).with(
        subject: guid,
        endpoints: [
          { testid: 'https://tests.example/one', endpoint: 'https://tests.example/one/api' },
          { testid: 'https://tests.example/two', endpoint: 'https://tests.example/two/api' }
        ],
        bmid: 'https://example.org/benchmark'
      )
      expect(algo.resultset).to eq(resultset)
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

    it 'maps fail, indeterminate, and unknown result values to their configured weights' do
      algo.tests = [
        { reference: 'T1', name: 'test:fail', pass_weight: 5.0, fail_weight: -100.0, indeterminate_weight: 0.0 },
        { reference: 'T2', name: 'test:indeterminate', pass_weight: 5.0, fail_weight: -1.0, indeterminate_weight: 0.5 },
        { reference: 'T3', name: 'test:unknown', pass_weight: 5.0, fail_weight: -1.0, indeterminate_weight: 0.5 }
      ]
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'test:fail').and_return(['fail', 'failed'])
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'test:indeterminate').and_return(['indeterminate', 'maybe'])
      allow(algo).to receive(:parse_single_test_response).with(resultset: resultset, testid: 'test:unknown').and_return(['unexpected', 'unknown'])

      results = algo.process_resultset

      expect(results['T1']).to include(result: 'fail', weight: -100.0, log: 'failed')
      expect(results['T2']).to include(result: 'indeterminate', weight: 0.5, log: 'maybe')
      expect(results['T3']).to include(result: 'unexpected', weight: 0.0, log: 'unknown')
    end
  end

  describe '#parse_single_test_response' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }
    let(:ftr) { RDF::Vocabulary.new('https://w3id.org/ftr#') }

    before do
      algo.resultsetgraph << RDF::Reader.for(:jsonld).new(StringIO.new(resultset))
    end

    it 'extracts the normalized result value and log for a matching test' do
      value, log = algo.parse_single_test_response(
        resultset: resultset,
        testid: 'https://tests.ostrails.eu/tests/fc_metadata_includes_license'
      )

      expect(value).to eq('pass')
      expect(log).to include('SUCCESS: Found')
    end

    it 'returns false when the test result is absent' do
      expect(algo.parse_single_test_response(resultset: resultset, testid: 'https://tests.example/missing')).to be false
    end

    it 'returns the first value when duplicate result scores are present' do
      result = RDF::URI('urn:multi-result')
      test = RDF::URI('https://tests.example/multi')
      algo.resultsetgraph << [result, RDF.type, ftr.TestResult]
      algo.resultsetgraph << [result, ftr.outputFromTest, test]
      algo.resultsetgraph << [result, RDF::Vocab::PROV.value, RDF::Literal.new('PASS')]
      algo.resultsetgraph << [result, RDF::Vocab::PROV.value, RDF::Literal.new('FAIL')]

      expect(algo.parse_single_test_response(resultset: resultset, testid: test.to_s).first).to eq('pass')
    end
  end

  describe '#extract_target_from_resultset' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset_with_target_identifier) }

    it 'extracts the assessed target identifier from the resultset' do
      expect(algo.extract_target_from_resultset).to eq('https://example.org/target')
    end

    it 'raises when no tested target identifier exists' do
      algo.resultset = { '@context' => {}, '@graph' => [] }.to_json

      expect { algo.extract_target_from_resultset }.to raise_error(RuntimeError, /no tested guid found/)
    end
  end

  describe '#generate_execution_output_rdf' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset) }

    before do
      algo.resultsetgraph << RDF::Reader.for(:jsonld).new(StringIO.new(resultset))
    end

    it 'creates benchmark score RDF linked to the source test result set' do
      graph = algo.generate_execution_output_rdf(output: { score: 0.99 }, algorithmid: algo.algorithm_id)

      expect(graph).to be_a(RDF::Graph)
      expect(graph.query([nil, RDF.type, Algorithm::FTR.BenchmarkScore]).count).to eq(1)
      expect(graph.query([nil, Algorithm::FTR.scoredTestResults, nil]).count).to eq(1)
    end

    it 'aborts when no TestResultSet URI is present' do
      empty_algo = described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, resultset: resultset)

      expect { empty_algo.generate_execution_output_rdf(output: {}, algorithmid: empty_algo.algorithm_id) }
        .to raise_error(SystemExit)
    end
  end

  describe '#register' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'posts the algorithm URL to the configured FDP index proxy' do
      response = double('RestClient::Response', body: '{"ok":true}')
      allow(RestClient::Request).to receive(:execute).and_return(response)

      expect(algo.register).to eq(response)
      expect(RestClient::Request).to have_received(:execute).with(
        method: :post,
        url: Configuration.fdp_index_proxy,
        payload: { 'clientUrl' => algo.algorithm_guid }.to_json,
        headers: { accept: 'application/json', content_type: 'application/json' },
        max_redirects: 10
      )
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
      allow_any_instance_of(Champion::Core).to receive(:get_test_endpoint_for_testid)
        .and_return('https://tests.ostrails.eu/assess/test/some_test/api')
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

    it 'reports invalid formulas and guidance parsing failures without raising' do
      algo.tests = [{ reference: 'T1' }]
      algo.conditions = [
        {
          formula: 'T1 > 0',
          success: 'success',
          failure: 'failure',
          guidance: 'malformed guidance'
        }
      ]
      allow_any_instance_of(Dentaku::Calculator).to receive(:evaluate).and_raise(Dentaku::ParseError, 'bad formula')

      narratives, guidances = algo.evaluate_conditions('T1' => { weight: 1.0 })

      expect(narratives.first).to include('Invalid formula')
      expect(narratives.last).to eq('failure')
      expect(guidances.first).to eq([])
    end

    it 'reports condition output failures without raising' do
      algo.tests = [{ reference: 'T1' }]
      algo.conditions = [{ formula: 'T1 < 0', success: nil, failure: 'failure', guidance: 'bad guidance' }]
      allow(algo).to receive(:parse_input_string).and_raise(StandardError, 'guidance failure')

      narratives, = algo.evaluate_conditions('T1' => { weight: 1.0 })

      expect(narratives).to include(match(/There was a problem solving/))
    end
  end

  describe '#parse_input_string' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'returns placeholders for nil guidance' do
      expect(algo.parse_input_string(nil)).to eq([nil, nil])
    end

    it 'parses valid guidance pairs' do
      expect(algo.parse_input_string('[[https://example.org/help, "Help text"]]')).to eq(
        [['https://example.org/help', 'Help text']]
      )
    end

    it 'marks invalid guidance URLs' do
      allow(algo).to receive(:valid_url?).and_return(false)

      expect(algo.parse_input_string('[[https://example.org/help, "Help text"]]')).to eq(
        [['', 'malformed guidance string, unable to parse']]
      )
    end

    it 'marks malformed guidance strings' do
      input = double('Guidance')
      allow(input).to receive(:strip).and_raise(StandardError)

      expect(algo.parse_input_string(input)).to eq([['', 'malformed guidance string, unable to parse']])
    end
  end

  describe '#valid_url?' do
    let(:algo) { described_class.new(calculation_uri: calculation_uri, baseURI: base_uri, guid: guid) }

    it 'accepts HTTP and HTTPS URLs' do
      expect(algo.valid_url?('http://example.org')).to be true
      expect(algo.valid_url?('https://example.org')).to be true
    end

    it 'rejects non-HTTP and malformed URLs' do
      expect(algo.valid_url?('ftp://example.org')).to be false
      expect(algo.valid_url?('http:// example.org')).to be false
    end
  end

  describe '.retrieve_by_id' do
    it 'maps an algorithm id to a Google spreadsheet URL' do
      expect(described_class.retrieve_by_id(algorithm_id: 'd/sheet-id')).to eq('https://docs.google.com/spreadsheets/d/sheet-id')
    end
  end

  describe '.list' do
    it 'queries the configured SPARQL endpoint and returns stringified solution bindings' do
      solution = double(
        'SPARQL::Client::Solution',
        bindings: {
          identifier: RDF::URI('https://tools.ostrails.eu/champion/algorithms/d/algo1'),
          title: RDF::Literal('Algorithm 1')
        }
      )
      client = instance_double('SPARQL::Client', query: [solution])
      allow(SPARQL::Client).to receive(:new).and_return(client)

      expect(described_class.list).to eq([
                                           {
                                             identifier: 'https://tools.ostrails.eu/champion/algorithms/d/algo1',
                                             title: 'Algorithm 1'
                                           }
                                         ])
      expect(SPARQL::Client).to have_received(:new).with(Configuration.fdpindex_sparql)
    end
  end

  describe '.generate_assess_algorithm_openapi' do
    it 'builds an OpenAPI document for the algorithm assessment endpoint' do
      spec = described_class.generate_assess_algorithm_openapi(algorithmid: 'd/algo1')
      path_key = spec[:paths].keys.first

      expect(spec[:openapi]).to eq('3.0.3')
      expect(path_key.to_s).to eq('/assess/algorithm/d/algo1')
      expect(spec[:paths][path_key][:post][:responses]).to include(:'200', :'400', :'404', :'406', :'500')
    end
  end
end
