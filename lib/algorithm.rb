require 'rdf'
require 'rdf/ntriples'
require 'rdf/vocab'
require 'json/ld' # For JSON-LD parsing support
require 'csv'
require 'rest-client'
require 'sparql/client'
require 'json'
require 'linkeddata'
require 'uri'
require_relative 'dcat_extractor'

# The Algorithm class processes scoring algorithms defined in Google Spreadsheets,
# integrating with RDF data and external services to execute tests, process results,
# and generate semantic outputs.
class Algorithm
  include RDF

  # RDF Vocabulary for DCAT, as the built-in DCAT vocab does not recognize "version".
  DCAT = RDF::Vocabulary.new('http://www.w3.org/ns/dcat#')

  # RDF Vocabulary for FTR (FAIR Test Registry).
  FTR = RDF::Vocabulary.new('https://w3id.org/ftr#')

  # RDF Vocabulary for VIVO ontology.
  VIVO = RDF::Vocabulary.new('http://vivoweb.org/ontology/core#')

  # RDF Vocabulary for SIO (Semanticscience Integrated Ontology).
  SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')

  # RDF Vocabulary for DOAP (Description of a Project).
  DOAP = RDF::Vocab::DOAP

  # RDF Vocabulary for VCARD (vCard Ontology).
  VCARD = RDF::Vocab::VCARD

  # RDF Vocabulary for Dublin Core Terms.
  DC = RDF::Vocab::DC

  # RDF Vocabulary for PROV-O (Provenance Ontology).
  PROV = RDF::Vocab::PROV

  # curl -v -L -H "content-type: application/json"
  # -d '{"clientUrl": "https://my.domain.org/path/to/DCAT/record.ttl"}'
  # https://tools.ostrails.eu/fdp-index-proxy/proxy

  # Mapping of DCAT properties to RDF predicates for metadata extraction.
  # @return [Hash<Symbol, RDF::URI>] A frozen hash mapping property names to RDF predicates.
  PREDICATES = { title: DC.title,
                 version: DCAT.version,
                 description: DC.description,
                 endpointtDescription: DCAT.endpointDescription,
                 endpointURL: DCAT.endpointURL,
                 keyword: DCAT.keyword,
                 abbreviation: VIVO.abbreviation,
                 repository: DOAP.repository,
                 type: DC.type,
                 license: DC.license,
                 applicationArea: FTR.applicationArea,
                 isApplicableFor: FTR.isApplicableFor,
                 isImplementationOf: SIO['SIO_000233'], # points to benchmark
                 scoringFunction: FTR.scoringFunction, # points to google sheet
                 contactPoint: DCAT.contactPoint }.freeze

  # @!attribute calculation_uri
  #   @return [String] The URI of the Google Spreadsheet defining the algorithm.
  # @!attribute baseURI
  #   @return [String] The base URI for the application (default: 'https://tools.ostrails.eu/champion').
  # @!attribute csv
  #   @return [Array<String>] Lines of the CSV data fetched from the Google Spreadsheet.
  # @!attribute algorithm_id
  #   @return [String] The unique identifier extracted from the Google Spreadsheet URI.
  # @!attribute algorithm_guid
  #   @return [String] The globally unique identifier for the algorithm (e.g., "#{baseURI}/algorithms/#{algorithm_id}").
  # @!attribute guid
  #   @return [String, nil] The GUID of the digital object to assess (optional if resultset is provided).
  # @!attribute resultset
  #   @return [String, nil] The JSON-LD result set from a previous test execution (optional if guid is provided).
  # @!attribute resultsetgraph
  #   @return [RDF::Graph] The RDF graph representation of the resultset.
  # @!attribute valid
  #   @return [Boolean] Indicates if the algorithm is valid (requires a Google Spreadsheet URI and either guid or resultset).
  # @!attribute metadata
  #   @return [RDF::Graph] The RDF graph containing metadata about the algorithm.
  # @!attribute graph
  #   @return [RDF::Graph] A general-purpose RDF graph for the algorithm (currently unused).
  # @!attribute tests
  #   @return [Array<Hash>] List of test configurations parsed from the CSV.
  # @!attribute benchmarkguid
  #   @return [String] The GUID of the benchmark the algorithm implements.
  # @!attribute conditions
  #   @return [Array<Hash>] List of conditions parsed from the CSV for evaluating test results.
  attr_accessor :calculation_uri, :baseURI, :csv, :algorithm_id, :algorithm_guid,
                :guid, :resultset, :resultsetgraph,
                :valid, :metadata, :graph, :tests,
                :benchmarkguid, :conditions

  # Initializes a new Algorithm instance by fetching configuration from a Google Spreadsheet.
  #
  # @param calculation_uri [String] The URI of the Google Spreadsheet containing algorithm configuration.
  # @param baseURI [String] The base URI for the application (default: 'https://tools.ostrails.eu/champion').
  # @param guid [String, nil] The GUID of the digital object to assess (optional if resultset is provided).
  # @param resultset [String, nil] The JSON-LD result set from a previous test execution (optional if guid is provided).
  # @return [Algorithm] A new instance of the Algorithm class.
  # @raise [RestClient::Exception] If the HTTP request to fetch the CSV fails.
  # @example
  #   algo = Algorithm.new(
  #     calculation_uri: 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w',
  #     guid: 'https://example.org/target/456'
  #   )
  def initialize(calculation_uri:, baseURI: 'https://tools.ostrails.eu/champion', guid: nil, resultset: nil)
    @calculation_uri = calculation_uri
    @baseURI = baseURI
    @guid = guid
    @resultset = resultset
    @resultsetgraph = RDF::Graph.new
    @graph = RDF::Graph.new # this seems to only be used for parsing incoming resultsets from other tools
    @metadata = RDF::Graph.new
    @tests = []
    @conditions = []
    @valid = false
    @benchmarkguid = ''
    # Must be a google docs template and either a guid to test or the inut from another tools resultset
    @valid = true if @calculation_uri =~ %r{docs\.google\.com/spreadsheets} && (guid || resultset)
    # spreadsheets/d/  --> 16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w

    # NOTA BENE
    @algorithm_id = @calculation_uri.match(%r{/spreadsheets/(\w/[^/]+)})[1] # d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w  (note the d/ !!)
    #  NOTA BENE!  This same match apears in _algo_list.erb, so if you change it here, change it there!

    @algorithm_guid = "#{@baseURI}/algorithms/#{algorithm_id}"
    # Transform the spreadsheet URL to CSV export format
    # https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w/edit?gid=0#gid=0
    calculation_uri = calculation_uri.sub(%r{/edit.*$}, '')
    calculation_uri = calculation_uri.sub(%r{/$}, '') # remove trailing slash also
    csv_url = "#{calculation_uri}/export?exportFormat=csv"
    # Use RestClient with follow redirects (default max_redirects is 10)
    warn "executing get on #{csv_url} with good headers"

    response = RestClient::Request.execute(
      method: :get,
      url: csv_url,
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
        'Accept' => 'text/csv, text/plain, application/octet-stream, */*',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Referer' => 'https://docs.google.com/',
        'Connection' => 'keep-alive'
      },
      max_redirects: 10
    )
    # Split CSV into lines to identify blocks
    warn "response is #{response.inspect}"
    @csv = response.body.lines
  end

  # Processes the algorithm by loading configuration, running tests (if needed), and evaluating results.
  #
  # @return [Hash] A hash containing metadata, test results, narratives, resultset, and tested GUID.
  # @example
  #   algo = Algorithm.new(calculation_uri: 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w', guid: 'https://example.org/target/456')
  #   result = algo.process
  #   puts result[:narratives]
  def process
    load_configuration
    warn "\n\n\nABOUT TO RUN TESTS\n\n\n" unless resultset
    run_tests unless resultset # from-scratch or using the input resultset?
    # at this point, @resultset variable definitely exists, so now make it a graph to reduce future parsing time
    format = :jsonld
    resultsetgraph << RDF::Reader.for(format).new(resultset)

    # this is a special case where we need the target GUID as an independent piece of metadata
    testedguid = extract_target_from_resultset

    test_results = process_resultset
    narratives, guidances = evaluate_conditions(test_results)
    {
      metadata: metadata,
      test_results: test_results,
      narratives: narratives,
      resultset: resultset,
      testedguid: testedguid,
      guidances: guidances
    }
  end

  # Gathers metadata from the CSV and constructs an RDF graph.
  #
  # @return [RDF::Graph] The RDF graph containing the algorithm's metadata.
  # @raise [RuntimeError] If the CSV does not contain at least two empty lines.
  # @example
  #   algo = Algorithm.new(calculation_uri: 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w', guid: 'https://example.org/target/456')
  #   metadata = algo.gather_metadata
  #   puts metadata.dump(:turtle)
  def gather_metadata
    # Find separator lines (containing only commas, whitespace, or empty after strip)
    empty_line_indices = csv.each_with_index.select { |line, _| line.strip.gsub(/,+/, '').empty? }.map(&:last)

    # Ensure we have at least two empty lines to separate three blocks
    if empty_line_indices.size < 2
      raise 'Invalid CSV structure: Expected at least two empty lines to separate three blocks'
    end

    # Parse metadata block (rows 0 to first empty line, with header)
    metadata_csv = csv[2...empty_line_indices[1]].join # the first empty line is below the template  version, so we ignore it
    csv_data = CSV.parse(metadata_csv, headers: true)
    warn "\n\nTHE CSV DATA IS #{csv_data}\n\n"
    subject = RDF::URI.new(algorithm_guid)

    # metadata is an RDF__Graph
    csv_data.each do |row|
      warn "\n\nINSPECTING ROW \n #{row.inspect}\n\n"
      warn "dcat property #{row['DCAT Property']}"
      next if row['DCAT Property'].strip == 'isImplementationOf' && !@benchmarkguid = row['Value']

      # Process COntactPoint separately
      if row['DCAT Property'].strip == 'contactPoint'
        uniqid = Time.now.to_i
        contactnode = RDF::URI.new("urn:local:champion:contactpoint:#{uniqid}")
        predicate = PREDICATES[:contactPoint]
        metadata << RDF::Statement.new(subject, predicate, contactnode)
        metadata << RDF::Statement.new(contactnode, RDF.type, VCARD.Individual)
        metadata << RDF::Statement.new(contactnode, VCARD.hasEmail, RDF::Literal.new(row['Value']))
        next
      end

      predicate = PREDICATES[row['DCAT Property'].strip.to_sym]
      # warn "working with predicate #{predicate}"
      predicate ||= RDF::URI.new("urn:unknown_property:#{row['DCAT Property']}")
      value = row['Value']
      value = if value =~ %r{^https?://}
                RDF::URI.new(value)
              else
                RDF::Literal.new(value)
              end
      metadata << RDF::Statement.new(subject, predicate, value)
    end

    # Now get the Tests block
    test_csv = csv[empty_line_indices[1] + 1...empty_line_indices[2]].join # the first empty line is below the template  version, so we ignore it
    csv_data = CSV.parse(test_csv, headers: true)
    warn "\n\nTHE TEST DATA IS #{csv_data}\n\n"

    # Test referenes are part of the Algorithm DCAT
    c = Champion::Core.new # needed for registry lookup
    @tests = csv_data.map do |row|
      {
        reference: row['Test Reference'],
        name: row['Test GUID'],
        testid: row['Test GUID'],
        endpoint: c.get_test_endpoint_for_testid(testid: row['Test GUID']),
        pass_weight: row['Pass Weight'].to_f,
        fail_weight: row['Fail Weight'].to_f,
        indeterminate_weight: row['Indeterminate Weight'].to_f
      }
    end
    warn "TESTS:  #{@tests.inspect}"

    metadata << RDF::Statement.new(subject, RDF.type, FTR.ScoringAlgorithm)
    metadata << RDF::Statement.new(subject, RDF.type, DCAT.DataService)
    metadata << RDF::Statement.new(subject, DC.identifier, subject)

    endpoint = "#{baseURI}/assess/algorithm/#{algorithm_id}"
    metadata << RDF::Statement.new(subject, DCAT.endpointDescription, RDF::URI.new(endpoint))
    metadata << RDF::Statement.new(subject, DCAT.endpointURL, RDF::URI.new(endpoint))
    metadata << RDF::Statement.new(subject, FTR.scoringFunction, RDF::URI.new(calculation_uri))

    # Finally, add the tests
    @tests.each do |t|
      metadata << RDF::Statement.new(subject, FTR.invokesTest, RDF::URI.new(t[:testid]))
    end

    metadata
  end

  # Parses the Google Spreadsheet CSV into metadata, tests, and conditions.
  #
  # @return [void]
  # @raise [RuntimeError] If the CSV does not contain at least two empty lines to separate metadata, tests, and conditions.
  # @example
  #   algo = Algorithm.new(calculation_uri: 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w', guid: 'https://example.org/target/456')
  #   algo.load_configuration
  #   puts algo.tests
  #   puts algo.conditions
  def load_configuration
    gather_metadata # sets value for @metadata

    empty_line_indices = csv.each_with_index.select { |line, _| line.strip.gsub(/,+/, '').empty? }.map(&:last)
    # Ensure we have at least two empty lines to separate three blocks
    if empty_line_indices.size < 2
      raise 'Invalid CSV structure: Expected at least two empty lines to separate three blocks'
    end

    # Parse conditions (remaining rows after empty row)
    # Parse conditions block (rows after second separator, with header)
    condition_csv = csv[(empty_line_indices[2] + 1)..-1].join
    csv_data = CSV.parse(condition_csv, headers: true)
    @conditions = csv_data.map do |row|
      {
        condition: row['Condition'],
        description: row['Description'],
        formula: row['Formula'],
        success: row['Success Message'],
        failure: row['Fail Message'],
        guidance: row['Guidance'] # strucdture is [[URL, "desc"], [URL, "desc"]]
      }
    end

    # Store in RDF graph
    # build_rdf_graph
  end

  # Generates an RDF graph representing the benchmark score for the algorithm execution.
  #
  # @param output [Hash] The output from the #process method, containing metadata, test results, narratives, and resultset.
  # @param algorithmid [String] The unique identifier of the algorithm.
  # @return [RDF::Graph] An RDF graph containing the benchmark score and associated metadata.
  # @raise [RuntimeError] If no TestResultSet URI is found in the resultset graph.
  # @example
  #   algo = Algorithm.new(calculation_uri: 'https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w', guid: 'https://example.org/target/456')
  #   output = algo.process
  #   rdf_graph = algo.generate_execution_output_rdf(output: output, algorithmid: algo.algorithm_id)
  def generate_execution_output_rdf(output:, algorithmid:) # output is the object above here... with metadata, test results, narratives, and resultset
    benchmarkscore = RDF::Graph.new
    uniqid = Time.now.to_i
    subject = RDF::URI.new("https://tools.ostrails.eu/champion/assess/algorithm/#{algorithmid}/result_#{uniqid}")
    activity = RDF::URI.new("https://tools.ostrails.eu/champion/assess/algorithm/#{algorithmid}/result_#{uniqid}/activity")
    benchmarkscore << RDF::Statement.new(subject, RDF.type, FTR.BenchmarkScore)
    benchmarkscore << RDF::Statement.new(subject, PROV.wasGeneratedBy, activity)
    benchmarkscore << RDF::Statement.new(activity, RDF.type, FTR.ScoringAlgorithmActivity)
    benchmarkscore << RDF::Statement.new(subject, PROV.value, RDF::Literal.new(0.99))
    benchmarkscore << RDF::Statement.new(subject, FTR.log, RDF::Literal.new(output))
    benchmarkscore << RDF::Statement.new(subject, FTR.outputFromAlgorithm, RDF::URI.new(algorithm_guid))

    # need the id of the resultset object
    test_result_set_uri = nil
    type_predicate = RDF::URI('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
    test_result_set_type = RDF::URI('https://w3id.org/ftr#TestResultSet')

    resultsetgraph.query([nil, type_predicate, test_result_set_type]) do |statement|
      test_result_set_uri = statement.subject
      break # Assuming only one such URI
    end

    if test_result_set_uri
      warn "Found TestResultSet URI: #{test_result_set_uri}"
    else
      abort 'No TestResultSet URI found in the graph.'
    end

    benchmarkscore << RDF::Statement.new(subject, FTR.scoredTestResults, test_result_set_uri)
    benchmarkscore << resultsetgraph # add the resultset to the benchmarkscore graph object
    benchmarkscore # send back as RDF::Graph object
  end

  def register # initialize has already been called so all vars are full
    # algorithmfilenmae = algorithm_id.gsub("/", "__")
    # filename = "/cache/#{algorithmfilenmae}" # I need to know this exactly one time, to create the metadata when the object is not yet registered!

    # Store the mapping in a file
    # File.write(filename, { calculation_uri => algorithm_guid }.to_json)
    # warn 'Stored mapping'

    # curl -v -L -H "content-type: application/json"
    # -d '{"clientUrl": "https://my.domain.org/path/to/DCAT/record.ttl"}'
    # https://tools.ostrails.eu/fdp-index-proxy/proxy
    # Configuration.fdp_index_proxy = ENV['Configuration.fdp_index_proxy'] || "https://tools.ostrails.eu/fdp-index-proxy/proxy"
    # get '/champion/algorithms/:algorithm'

    warn "client url is #{algorithm_guid}"
    RestClient::Request.execute(
      method: :post,
      url: Configuration.fdp_index_proxy,
      payload: { 'clientUrl' => algorithm_guid }.to_json, # this needs to respond with DCAT, so I use the proxy at algorithm_guid (set in initialize)
      headers: { accept: 'application/json', content_type: 'application/json' },
      max_redirects: 10
    )
  end

  def self.retrieve_by_id(algorithm_id:)
    # Check if file exists
    # THE PROBLEM:  we cannot predict the Google Sheets URI, but we need it to create the object
    # so get it from the cache, or get it from the FDP Index
    # if File.exist?("/cache/#{algorithm_id}") # this is the first time it has been called, so need to get calculation_uri from cache
    #   # Read and parse the mapping
    #   warn 'RETRIEVING FROM CACHE'
    #   mapping = ::JSON.parse(File.read("/tmp/#{algorithm_id}"))
    #   calculation_uri, algorithm_guid = mapping.first

    #   #      File.delete("/tmp/#{algorithm_id}") if File.exist?("/tmp/#{algorithm_id}")

    #   warn "Retrieved: #{calculation_uri}, #{algorithm_guid}"
    #   calculation_uri
    # else
    # if that temp mapping file doesn't exist, then the data is in the FDP registry, so we can get it from there...
    #     query = <<EOQ
    #       PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    #       PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    #       PREFIX dqv: <http://www.w3.org/ns/dqv#>
    #       PREFIX dct: <http://purl.org/dc/terms/>
    #       PREFIX dcat: <http://www.w3.org/ns/dcat#>
    #       PREFIX sio: <http://semanticscience.org/resource/>
    #       PREFIX dpv: <http://www.w3.org/ns/dpv#>
    #       PREFIX ftr: <https://w3id.org/ftr#>
    #       SELECT distinct ?identifier ?scoringfunction WHERE {
    #         ?subject a <https://w3id.org/ftr#ScoringAlgorithm> ;
    #           dct:identifier ?identifier ;
    #           ftr:scoringFunction ?scoringfunction .
    #           FILTER(CONTAINS(str(?identifier), "/champion/"))
    #           FILTER(CONTAINS(str(?identifier), "#{algorithm_id}"))
    #       }#{' '}
    # EOQ

    #       warn "query is #{query}"
    #       endpoint = SPARQL::Client.new(Configuration.fdpindex_sparql)

    #       begin
    #         # Execute the query
    #         results = endpoint.query(query)
    #         warn "results:   #{results.inspect}"
    #         return false unless results.first

    #         solution = results.first
    #         warn "solution:   #{solution.inspect}"

    #         solution[:scoringfunction].to_s # this is the calculation_uri requried to initialize the object
    #       end
    # end
    # inthe end just hard-code the algorithm id as a google id.  We can create a more sophisticated approach alter
    "https://docs.google.com/spreadsheets/#{algorithm_id}"
  end

  # Run tests and collect results
  def run_tests
    endpoints = @tests.map { |test| test[:endpoint] }
    c = Champion::Core.new
    # resultset is an instance attribute, so set it here
    @resultset = c.execute_on_endpoints(subject: guid, endpoints: endpoints, bmid: benchmarkguid) # ResultSet is the shared datastructure in the IF
    # resultset is jsonld
  end

  def process_resultset
    # warn "RESULT SET", result_set, "\n\n"
    # Result Set is a  JSON LD String

    # two possibilities - the resultset is created by us, and all tests match the tests in the load_configuration
    # or it was passed to us from another app
    # either way, extract the test IDs from the resultset object
    # ....no.... this isn't necessary... if they aren't in the algorithm, then we cant deal with them anyway!
    # @resultset_testids = extract_tests_from_resultset

    results = {}
    @tests.each do |test| # the tests defined in the algorithm
      passfail = parse_single_test_response(resultset: @resultset, testid: test[:name]) # extract result for THAT test from the restul-set
      results[test[:reference]] = if passfail # if there's a value, then the test existed
                                    {
                                      result: passfail,
                                      weight: case passfail
                                              when 'pass' then test[:pass_weight]
                                              when 'fail' then test[:fail_weight]
                                              when 'indeterminate' then test[:indeterminate_weight]
                                              else 0.0
                                              end
                                    }
                                  else # the resultset didn't contain that test... so we will give it an "indeterminate"
                                    {
                                      result: 'indeterminate (result data not found)',
                                      weight: test[:indeterminate_weight]
                                    }
                                  end
    end
    results
  end

  # Stub for test response parsing (to be implemented in your existing codebase)
  def parse_single_test_response(resultset:, testid:)
    # warn 'GRAPH:', graph.dump(:turtle), "\n\n"
    # <urn:ostrails:testexecutionactivity:42c79dfe-fc9a-40db-84b6-6a3e69b8afab> a <https://w3id.org/ftr#TestExecutionActivity>;
    #   prov:generated <urn:fairtestoutput:2152d30f-516c-43da-b647-4f4726c33fbb>;
    #   prov:used <https://w3id.org/duchenne-fdp>;
    #   prov:wasAssociatedWith <https://tests.ostrails.eu/tests/fc_metadata_includes_license> .
    # <urn:fairtestoutput:2152d30f-516c-43da-b647-4f4726c33fbb> a <https://w3id.org/ftr#TestResult>;
    #   prov:value "pass"@en;
    prov = RDF::Vocab::PROV
    ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
    warn 'PROV: ', prov.inspect, "\n\n"
    warn 'FTR: ', ftr.inspect, "\n\n"
    solutions = RDF::Query.execute(resultsetgraph) do
      pattern [:execution, RDF.type, ftr.TestExecutionActivity]
      pattern [:result, prov.wasGeneratedBy, :execution]
      pattern [:result, RDF.type, ftr.TestResult]
      pattern [:result, prov.value, :value]
    end
    warn "SOLUTIONS for <#{testid}>", solutions.inspect, "\n"

    passfail = solutions.map { |solution| solution[:value].to_s }.uniq
    if passfail.empty?
      warn "no score found for test #{testid}" # this hapens when the user has passed a resultset that doesn't align with the algorithm
      return false
    elsif passfail.size > 1
      warn 'Warning: Multiple scores found.  Returning only the first one.'
    end

    passfail.first
  end

  # def extract_tests_from_resultset
  #   warn "extract tests from resultset"

  #   format = :jsonld
  #   graph = RDF::Graph.new
  #   graph << RDF::Reader.for(format).new(resultset)
  #   ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
  #   # warn 'PROV: ', prov.inspect, "\n\n"
  #   # warn 'FTR: ', ftr.inspect, "\n\n"
  #   solutions = RDF::Query.execute(graph) do
  #     pattern [:result, RDF.type, ftr.TestResult]
  #     pattern [:result, ftr.outputFromTest, :test]
  #     pattern [:test, RDF.type, ftr.Test]
  #     pattern [:test, RDF::Vocab::DC.identifier, :testid]
  #   end
  #   warn 'SOLUTIONS to find the tests in a TestResult ', solutions.inspect, "\n"

  #   testids = solutions.map { |solution| solution[:testid].to_s }.uniq
  #   raise 'no tests found in the resultset... which is very odd!' if passfail.empty?

  #   testids
  # end

  def extract_target_from_resultset
    warn 'extract target from resultset'
    format = :jsonld
    graph = RDF::Graph.new
    graph << RDF::Reader.for(format).new(resultset)
    ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

    solutions = RDF::Query.execute(graph) do
      pattern [:result, RDF.type, ftr.TestResultSet]
      pattern [:result, ftr.assessmentTarget, :target]
      # pattern [:target, RDF.type, prov.Entity]
      pattern [:target, RDF::Vocab::DC.identifier, :testedguid]
    end
    warn 'SOLUTIONS to find the tested target in a TestResultSet ', solutions.inspect, "\n"

    guids = solutions.map { |solution| solution[:testedguid].to_s }.uniq # should return a list of one... hopefully!
    raise "no tested guid found in the resultset #{guids.inspect}... which is very odd!" if guids.empty?

    guids.first # can be only one
  end

  # Evaluate conditions and generate narratives
  def evaluate_conditions(test_results)
    # results[T1] = {
    #   result: "pass",
    #   weight: 10
    # } ...

    narratives = []
    guidances = []
    @conditions.each do |condition|
      # {
      #   condition: row['Condition'],
      #   description: row['Description'],
      #   formula: row['Formula'],
      #   success: row['Success Message'],
      #   failure: row['Fail Message'],
      #   guidance: row['Guidance']
      # }

      formula = condition[:formula]
      @tests.each do |test|
        #         {
        #   reference: row['Test Reference'],  # e.g. T1
        #   name: row['Test GUID'],
        #   testid: row['Test GUID'],
        #   endpoint: get_test_endpoint_for_testid(testid: row['Test GUID']),
        #   pass_weight: row['Pass Weight'].to_f,
        #   fail_weight: row['Fail Weight'].to_f,
        #   indeterminate_weight: row['Indeterminate Weight'].to_f
        # }
        result = test_results[test[:reference]]
        formula.gsub!(test[:reference], result[:weight].to_s)
      end
      begin
        # Evaluate the formula (e.g., "A1 + B1 > 1.0")
        is_met = eval(formula)
        # I DON'T LIKE THIS... it should be a hash to ensure alignment of narrative with guidance
        # TODO
        narratives << if is_met
                        condition[:success]
                      else
                        condition[:failure]
                      end
        guidances << if is_met
                       [] # guidance is only necessary on failure
                     else
                       parse_input_string(condition[:guidance]) # add guidance block [URL, string] in case of failure
                     end
      rescue StandardError => e
        narratives << "Problem solving for #{formula} #{e}; "
      end
    end
    [narratives, guidances]
  end

  def parse_input_string(input_string)
    # Remove outer brackets
    content = input_string.strip[1..-2]

    # Regex to match [url, "title"] pairs
    pattern = %r{\[(https?://[^,\]]+),\s*"([^"]*)"\]}

    # Find all matches
    matches = content.scan(pattern)

    result = []
    matches.each do |url, title|
      # Validate URL
      if valid_url?(url.strip)
        result << [url.strip, title.strip]
      else
        puts "Skipping invalid URL: #{url}"
      end
    end

    result
  end

  def valid_url?(url)
    uri = ::URI.parse(url)
    uri.is_a?(::URI::HTTP) || uri.is_a?(::URI::HTTPS)
  rescue ::URI::InvalidURIError
    false
  end

  # get all algorithms
  def self.list
    client = SPARQL::Client.new(Configuration.fdpindex_sparql)

    algossquery = <<EOQ
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dqv: <http://www.w3.org/ns/dqv#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <http://www.w3.org/ns/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT ?identifier ?title ?description ?endpoint ?calculation_uri ?openapi (GROUP_CONCAT(?objects; separator=", ") AS ?objects) (GROUP_CONCAT(?domain; separator=", ") AS ?domains) ?benchmark
      WHERE {
        ?subject a <https://w3id.org/ftr#ScoringAlgorithm> ;
            dct:title ?title ;
            dct:description ?description ;
            dct:identifier ?identifier ;
            dcat:endpointDescription ?openapi ;
            dcat:endpointURL ?endpoint .
        OPTIONAL { ?subject ftr:isApplicableFor ?objects }
        OPTIONAL { ?subject ftr:applicationArea ?domain }
        OPTIONAL { ?subject sio:SIO_000233 ?benchmark }
        OPTIONAL { ?subject ftr:scoringFunction ?calculation_uri}
      }
      GROUP BY ?identifier ?title ?description ?endpoint ?openapi ?benchmark ?calculation_uri
EOQ

    results = client.query(algossquery)

    results.map do |solution|
      solution.bindings.transform_values(&:to_s)
    end
    # warn alltests.to_json
  end

  # Function to generate OpenAPI spec for the assess algorithm endpoint
  def self.generate_assess_algorithm_openapi(algorithmid:)
    {
      openapi: '3.0.3',
      info: {
        title: 'Champion Benchmark Algorithm Execution API',
        description: 'API specification for assessing a specific benchmark over a digital object',
        version: '1.0.0'
      },
      servers: [
        {
          url: 'http://{host}/champion',
          variables: {
            host: {
              default: 'tools.ostrails.eu'
            }
          }
        }
      ],
      paths: {
        "/assess/algorithm/#{algorithmid}": {
          post: {
            summary: 'Execute algorithm assessment',
            parameters: [
              {
                name: 'algorithmid',
                in: 'path',
                required: true,
                schema: {
                  type: 'string'
                },
                description: 'The ID of the algorithm, embedded in the URL path (e.g., /assess/algorithm/my_algo_id).'
              }
            ],
            requestBody: {
              required: true,
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    properties: {
                      guid: {
                        type: 'string',
                        description: 'GUID for the assessment (optional if resultset is provided).'
                      },
                      resultset: {
                        type: 'string',
                        description: 'Result set data for the assessment (optional if guid is provided).'
                      }
                    },
                    description: "At least one of 'guid' or 'resultset' must be provided."
                  }
                },
                'multipart/form-data': {
                  schema: {
                    type: 'object',
                    properties: {
                      file: {
                        type: 'string',
                        format: 'binary',
                        description: 'Uploaded file containing the result set.'
                      }
                    },
                    description: 'A file containing the result set data.'
                  }
                }
              }
            },
            responses: {
              '200': {
                description: 'Returns algorithm execution result',
                content: {
                  'text/html': {
                    schema: {
                      type: 'string'
                    }
                  },
                  'application/json': {
                    schema: {
                      type: 'object'
                    }
                  },
                  'application/ld+json': {
                    schema: {
                      type: 'object'
                    }
                  }
                }
              },
              '400': {
                description: 'Missing required input (GUID, ResultSet, or file)',
                content: {
                  'text/html': {
                    schema: {
                      type: 'string'
                    }
                  }
                }
              },
              '404': {
                description: 'Invalid algorithm ID',
                content: {
                  'text/html': {
                    schema: {
                      type: 'string'
                    }
                  }
                }
              },
              '406': {
                description: 'Invalid data provided',
                content: {
                  'text/html': {
                    schema: {
                      type: 'string'
                    }
                  }
                }
              },
              '500': {
                description: 'Server error during processing',
                content: {
                  'text/html': {
                    schema: {
                      type: 'string'
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end

# Build RDF graph for semantic representation
# not sure this is useful....??
# def build_rdf_graph
#   algo = RDF::URI.new(@calculation_uri)
#   graph << [algo, RDF.type, RDF::URI.new('https://w3id.org/ftr#Algorithm')]
#   metadata.each do |key, value|
#     graph << [algo, RDF::URI.new("http://example.org/#{key}"), value]
#   end

#   tests.each do |test|
#     # reference: row['Test Reference'],
#     # name: row['Test GUID'],
#     # testid: row['Test GUID'],
#     # endpoint: get_test_endpoint_for_testid(testid: row['Test GUID'])
#     # pass_weight: row['Pass Weight'].to_f,
#     # fail_weight: row['Fail Weight'].to_f,
#     # indeterminate_weight: row['Indeterminate Weight'].to_f

#     test_uri = RDF::URI.new(test[:testid])
#     graph << [test_uri, RDF.type, RDF::URI.new('http://example.org/Test')]
#     graph << [test_uri, RDF::URI.new('http://example.org/reference'), test[:reference]]
#     graph << [test_uri, RDF::URI.new('http://example.org/identifier'), test[:name]]
#     graph << [test_uri, RDF::URI.new('http://example.org/endpoint'), test[:endpoint]]
#     graph << [test_uri, RDF::URI.new('http://example.org/passWeight'), test[:pass_weight]]
#     graph << [test_uri, RDF::URI.new('http://example.org/failWeight'), test[:fail_weight]]
#     graph << [test_uri, RDF::URI.new('http://example.org/indeterminateWeight'), test[:indeterminate_weight]]
#     graph << [algo, RDF::URI.new('http://example.org/hasTest'), test_uri]
#   end
# end
