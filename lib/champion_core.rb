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
      fdp_url = Configuration.fdpindex_sparql
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
      warn "\n\n\n\nQuery against #{fdp_url}  is \n#{query}\n\n\n\n"
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
      # endpoints = [{testid: test[:testid], endpoint: test[:endpoint] }...]
      results = []
      endpoints.each do |idpair|
        testid = idpair[:testid]
        endpoint = idpair[:endpoint]
        # warn 'benchmark point 2', endpoint.inspect
        results << run_test(guid: subject, testapi: endpoint, testid: testid) # this is a parsed JSON docuent returned
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
    def run_test(testapi:, guid:, testid:)
      warn "web api endpoint is at  #{testapi}"
      # testapi might be an external API!  So... be careful!
      # if testapi.match(/tests\.ostrails\.eu/)
      #   # MUNGE IT TEMPORARILY!
      #   # the asesss/test should really consume the name of the test, not the shortname
      #   testname = if testapi.match(%r{.*/(\S+)/api})
      #                testapi.match(%r{.*/(\S+)/api})[1]
      #              else
      #                testapi.match(%r{.*/(\S+)/?$})[1]
      #              end
      #   testurl = "https://tests.ostrails.eu/assess/test/#{testname}"
      # else
      #   testurl = testapi
      # end
      testurl = testapi
      warn "POINT FINAL:  Test URL is #{testurl}"
      RestClient.log = 'stderr' # Enable logging
      begin
        result = RestClient::Request.execute(
          url: testurl,
          method: :post,
          payload: { 'resource_identifier' => guid }.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        )
      rescue RestClient::ExceptionWithResponse => e
        warn "Test Execution failed with status: #{e.response.code}"
        warn "Error details: #{e.response.body}"
        return JSON.parse({ error: "#{testurl} did not respond happily.  Are you sure the test is registered? #{e.message}" }.to_json)
      rescue StandardError => e
        warn "Test Execution Unexpected error: #{e.message}"
        warn "#{testurl} did not respond happily"
        return JSON.parse({ error: "#{testurl} did not respond happily. Are you sure the test is registered? #{e.message}" }.to_json)
      end
      JSON.parse(result.body)
    end

    # ##############################################################
    #     TESTS
    # ##############################################################

    # Retrieves test metadata from the FDP SPARQL endpoint, optionally filtered by test ID.
    #
    # @param testid [String] The identifier of the test to retrieve (optional; full URI or local ID).
    # @return [Array<Champion::Test>] A list of Test object containing test metadata (identifier, title, description, etc.).
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
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <https://w3id.org/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT distinct ?identifier ?title ?description ?endpoint ?openapi ?dimension ?objects ?domain ?benchmark_or_metric WHERE {
        ?sub a <https://w3id.org/ftr#Test> ;
            dct:title ?title ;
            dct:description ?description ;
            dct:identifier ?identifier .
            OPTIONAL {?sub dcat:endpointDescription ?openapi }
            OPTIONAL {?sub dcat:endpointURL ?endpoint }
            # OPTIONAL {?sub dpv:inDimension ?dimension }
            OPTIONAL {?sub dpv:isApplicableFor ?objects }
            OPTIONAL {?sub ftr:applicationArea ?domain  }
            OPTIONAL {?sub sio:SIO_000233 ?benchmark_or_metric  }  # implementation of
      }
EOQ

      results = client.query(testsquery)

      results.select! { |res| res[:identifier].to_s =~ /#{testid}/ } if testid

      tests_by_id = Hash.new do |h, k|
        h[k] = {
          title: nil,
          description: nil,
          endpoint: nil,
          openapi: nil,
          # dimension: nil,
          objects: [],
          domain: [],
          benchmark_or_metric: nil
        }
      end

      results.each do |solution|
        id = solution[:identifier].to_s
        entry = tests_by_id[id]

        # Single-valued – keep first non-nil value
        entry[:title]       ||= solution[:title]&.to_s
        entry[:description] ||= solution[:description]&.to_s
        entry[:endpoint]    ||= solution[:endpoint]&.to_s
        entry[:openapi]     ||= solution[:openapi]&.to_s
        entry[:dimension]   ||= solution[:dimension]&.to_s
        entry[:benchmark_or_metric] ||= solution[:benchmark_or_metric]&.to_s
        # Multi-valued – collect unique values
        entry[:objects] << solution[:objects]&.to_s   if solution[:objects]
        entry[:domain]  << solution[:domain]&.to_s    if solution[:domain]
      end

      # build Champion::Test objects
      tests_by_id.map do |id, data|
        Champion::Test.new(
          identifier: id,
          title: data[:title],
          description: data[:description],
          endpoint: data[:endpoint],
          openapi: data[:openapi],
          dimension: data[:dimension],
          objects: data[:objects].to_a, # or .sort, .join(", "), etc.
          domain: data[:domain].to_a, # same
          benchmark_or_metric: data[:benchmark_or_metric]
        )
      end
    end

    def proxy_test(endpoint:, resource_identifier:)
      payload = {
        resource_identifier: resource_identifier.strip # or just 'xxxxx'
        # Add more fields if the API ever requires them in future
      }
      headers = {
        content_type: :json, # shorthand for 'application/json'
        accept: :json # tells server you'd like JSON back
        # 'Authorization': 'Bearer your-token'   # uncomment/add if needed
      }

      begin
        response = RestClient.post(
          endpoint,
          payload.to_json, # explicitly convert to JSON string
          headers
        )

        warn "Success! Status: #{response.code}"
        warn 'Response body:'
        warn response.body # usually JSON-LD or assessment result
      rescue RestClient::ExceptionWithResponse => e
        warn "Test Execution failed with status: #{e.response.code}"
        warn "Error details: #{e.response.body}"
      rescue StandardError => e
        warn "Test Execution Unexpected error: #{e.message}"
      end
      response.body # pass JSON back to caller for further processing
    end
  end
end
