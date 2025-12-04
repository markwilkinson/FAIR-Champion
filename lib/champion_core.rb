require 'rest_client'
require 'json'
require 'sparql'
require 'sparql/client'
require 'linkeddata'
require 'safe_yaml'
require 'rdf/nquads'

# The Champion module provides core functionality for executing assessments and tests
# against digital objects using RDF, SPARQL, and external APIs.
module Champion
  # The Core class handles assessment execution, test endpoint retrieval, and test execution
  # for the Champion application, interacting with SPARQL endpoints and external test APIs.
  class Core
    # @!attribute testhost
    #   @return [String, nil] The hostname for test services.
    # @!attribute champhost
    #   @return [String, nil] The hostname for the Champion application.
    attr_accessor :testhost, :champhost

    # Initializes a new Core instance.
    #
    # @return [Core] A new instance of the Core class.
    # @example
    #   core = Champion::Core.new
    def initialize; end

    # ################################# ASSESSMENTS
    # ########################################################################

    # Executes an assessment on a digital object using a specified test set.
    # Note: The method assumes the setid is either a full URI or local identifier,
    # and the API call should be verified in the application's routes.
    #
    # @param subject [String] The GUID of the digital object to assess.
    # @param setid [String] The identifier of the test set to use.
    # @return [String] A JSON-LD string representing the assessment results.
    # @todo Verify whether setid is a full URI or local identifier and confirm API call in routes.
    # @example
    #   core = Champion::Core.new
    #   result = core.run_assessment(subject: 'https://example.org/target/456', setid: 'test_set')
    #   puts result
    #
    # DEPRECATED??
    # def run_assessment(subject:, setid:)
    #   results = []
    #   warn "evaluating #{subject} on #{setid}"
    #   set = get_sets(setid: setid)
    #   warn 'point 1', set.inspect
    #   return results if set.empty?

    #   _graphid, setdef = set.first
    #   setdef[:tests].each do |testid|
    #     test, *_nada = get_tests(testid: testid) # returns an array of 1 element, so just get that into test
    #     warn 'point 2', test.inspect
    #     _id, testdef = test.first # there is only one, and it is guid => {features...}
    #     warn 'point 3', testdef.inspect

    #     results << run_test(guid: subject, testapi: testdef['api'])
    #   end
    #   # warn "RESULTS #{results}"
    #   output = Champion::Output.new(setid: "#{CHAMP_HOST}/sets/#{setid}", subject: subject)
    #   output.build_output(results: results) # returns jsonld
    # end

    # Executes a benchmark assessment on a digital object by retrieving associated metrics
    # and their test endpoints, then running tests.
    # Note: Future improvements may include using DCAT profiles in Accept headers.
    #
    # @param subject [String] The GUID of the digital object to assess.
    # @param bmid [String] The identifier of the benchmark (e.g., a URI resolving to DCAT).
    # @return [String] A JSON-LD string representing the benchmark assessment results.
    # @todo Implement DCAT profile support in Accept headers for RDF loading.
    # @example
    #   core = Champion::Core.new
    #   result = core.run_benchmark_assessment(subject: 'https://example.org/target/456', bmid: 'https://example.org/benchmark/123')
    #   puts result
    def run_benchmark_assessment(subject:, bmid:)
      # BMID is the id of the benchmark.  I resolve it to DCAT turtle (or whatever)
      # TODO THIS WILL EVENTUALLY USE the dcat profile in the Accept headers!
      #       repo = RDF::Repository.new
      #       repo.load("https://ruby-rdf.github.io/rdf/etc/doap.ttl",
      #           headers: { "Accept" => "text/turtle;q=1.0, application/rdf+xml;q=0.8" })
      #       puts "Loaded #{repo.count} statements"
      bm_dcat = RDF::Repository.load(bmid)
      query = <<-SPARQL
      SELECT ?metric
        WHERE { ?s <https://w3id.org/ftr#hasAssociatedMetric> ?metric }
      SPARQL
      solutions = SPARQL.execute(query, bm_dcat)
      metrics = # get the URIs of the metrics, to look-up in FDP
        solutions.map do |metricsol|
          metricsol[:metric].value
        end
      warn "FOUND METRICS #{metrics}"
      endpoints = []
      metrics.each do |metric|
        pairs = get_test_endpoints_for_metric(metric: metric)
        warn "FOUND ENDPOINT LIST PAIRS #{pairs.inspect}"
        pairs.each do |testid, endpoint|
          endpoints << [testid, endpoint]
        end
      end
      endpointurls = endpoints.map { |_testid, endpoint| endpoint }

      # now execute
      execute_on_endpoints(subject: subject, endpoints: endpointurls, bmid: bmid)
    end

    # Retrieves test endpoints associated with a given metric from the FDP index.
    #
    # @param metric [String] The URI of the metric (e.g., a DOI from FAIRsharing).
    # @return [Array<Array<String>>] A list of [testid, endpoint] pairs.
    # @example
    #   core = Champion::Core.new
    #   endpoints = core.get_test_endpoints_for_metric(metric: 'https://fairsharing.org/metric/123')
    #   puts endpoints
    def get_test_endpoints_for_metric(metric:)
      # metrics contains the Metric DOI from fairsharing.  Now lookip against FDP Index to get the tests
      # <http://semanticscience.org/resource/SIO_000233>
      # Define the remote SPARQL endpoint URL
      fdp_url = 'https://tools.ostrails.eu/repositories/fdpindex-fdp'
      # Create a SPARQL client instance
      client = SPARQL::Client.new(fdp_url)
      endpoints = []

      # Define your SPARQL query to get the associated test for a metric
      # TODO CAN I GET THE API HERE?  YES?
      query = <<-SPARQL
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        SELECT distinct ?testid ?endpoint WHERE {
          ?testid <http://semanticscience.org/resource/SIO_000233> <#{metric.strip}> . # is implementation of
          ?testid <http://www.w3.org/ns/dcat#endpointURL> ?endpoint .
        }
      SPARQL

      # Execute the query
      solutions = client.query(query)
      solutions.each do |result|
        endpoints << [result[:testid].value, result[:endpoint].value]
      end
      endpoints
    end

    # Retrieves the endpoint URL for a specific test ID from the FDP index.
    # Note: Consider retrieving directly from DCAT instead of the registry in the future.
    #
    # @param testid [String] The identifier of the test (full URI or local ID).
    # @return [String] The endpoint URL for the test.
    # @todo Explore retrieving endpoint directly from DCAT instead of the FDP registry.
    # @example
    #   core = Champion::Core.new
    #   endpoint = core.get_test_endpoint_for_testid(testid: 'https://tests.ostrails.eu/tests/test1')
    #   puts endpoint
    def get_test_endpoint_for_testid(testid:)
      # TODO: In principle we can get this directly from the DCAT, right??  Why use the registry?

      fdp_url = Configuration.fdpindex_sparql
      # Create a SPARQL client instance
      client = SPARQL::Client.new(fdp_url)
      # Define your SPARQL query to get the associated endpoint for a testid
      query = <<-SPARQL
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        SELECT distinct ?endpoint WHERE {
          <#{testid.to_s.strip}> <http://www.w3.org/ns/dcat#endpointURL> ?endpoint .
        }
      SPARQL

      # Execute the query
      solutions = client.query(query)
      solutions.first[:endpoint].value # can be onlhy one
    end

    # Executes tests on multiple endpoints and generates a JSON-LD result set.
    #
    # @param subject [String] The GUID of the digital object to assess.
    # @param endpoints [Array<String>] The list of test endpoint URLs.
    # @param bmid [String] The identifier of the benchmark.
    # @return [String] A JSON-LD string representing the test results.
    # @example
    #   core = Champion::Core.new
    #   endpoints = ['https://tests.ostrails.eu/assess/test/test1']
    #   result = core.execute_on_endpoints(subject: 'https://example.org/target/456', endpoints: endpoints, bmid: 'https://example.org/benchmark/123')
    #   puts result
    def execute_on_endpoints(subject:, endpoints:, bmid:)
      results = []
      endpoints.each do |endpoint|
        # warn 'benchmark point 2', endpoint.inspect
        results << run_test(guid: subject, testapi: endpoint)
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(benchmarkid: bmid, subject: subject)
      output.build_output(results: results) # returns jsonld
    end

    # Runs a single test against a test API endpoint.
    # Note: The test API URL is derived from the testapi parameter, which is temporarily munged to extract the test name.
    #
    # @param testapi [String] The API endpoint for the test.
    # @param guid [String] The GUID of the digital object to assess.
    # @return [Hash] The parsed JSON response from the test API.
    # @raise [RestClient::Exception] If the HTTP request to the test API fails.
    # @example
    #   core = Champion::Core.new
    #   result = core.run_test(testapi: 'https://tests.ostrails.eu/tests/test1/api', guid: 'https://example.org/target/456')
    #   puts result
    def run_test(testapi:, guid:)
      warn "web api is to #{testapi}"
      # testapi might be an external API!  So... be careful!
      if testapi.match(%r{tests\.ostrails\.eu})
        # MUNGE IT TEMPORARILY!
        # the asesss/test should really consume the name of the test, not the shortname
        testname = if testapi.match(%r{.*/(\S+)/api})
                    testapi.match(%r{.*/(\S+)/api})[1]
                  else
                    testapi.match(%r{.*/(\S+)/?$})[1]
                  end
        testurl = "https://tests.ostrails.eu/assess/test/#{testname}"
      else
        testurl = testapi
      end
      
      warn "POINT FINAL:  Test URL is #{testurl}"
      RestClient.log = 'stderr' # Enable logging
      result = RestClient::Request.execute(
        url: testurl,
        method: :post,
        payload: { 'resource_identifier' => guid }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )
      JSON.parse(result.body)
    end

    # ##############################################################
    #     TESTS
    # ##############################################################

    # Retrieves test metadata from the FDP SPARQL endpoint, optionally filtered by test ID.
    #
    # @param testid [String] The identifier of the test to retrieve (optional; full URI or local ID).
    # @return [Array<Hash>] A list of hashes containing test metadata (identifier, title, description, etc.).
    # @example
    #   core = Champion::Core.new
    #   tests = core.get_tests(testid: 'test1')
    #   tests.each { |test| puts test[:title] }
    def get_tests(testid: nil)
      warn 'IN GET TESTS'
      testid = testid.to_s.gsub(%r{.*/}, '') # if we are sent the entire URI, then just take the identifier part at the end

      sparqlurl = Configuration.fdpindex_sparql
      client = SPARQL::Client.new(sparqlurl)

      testsquery = <<EOQ
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dqv: <http://www.w3.org/ns/dqv#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <http://www.w3.org/ns/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT distinct ?identifier ?title ?description ?endpoint ?openapi ?dimension ?objects ?domain ?benchmark_or_metric WHERE {
        ?sub a <https://w3id.org/ftr#Test> ;
            dct:title ?title ;
            dct:description ?description ;
            dct:identifier ?identifier .
            OPTIONAL {?sub dcat:endpointDescription ?openapi }
            OPTIONAL {?sub dcat:endpointURL ?endpoint }
            OPTIONAL {?sub dqv:inDimension ?dimension }
            OPTIONAL {?sub dpv:isApplicableFor ?objects }
            OPTIONAL {?sub ftr:applicationArea ?domain  }
            OPTIONAL {?sub sio:SIO_000233 ?benchmark_or_metric  }  # implementation of
      }
EOQ

      results = client.query(testsquery)

      results.select! { |res| res[:identifier].to_s =~ /#{testid}/ } if testid

      results.map do |solution|
        solution.bindings.transform_values(&:to_s)
      end
      # warn alltests.to_json
    end
  end
end
