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
    # @!attribute reponame
    #   @return [String, nil] The name of the repository used for assessments.
    # @!attribute graphdbhost
    #   @return [String, nil] The hostname for the GraphDB instance.
    attr_accessor :testhost, :champhost, :reponame, :graphdbhost

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
    def run_assessment(subject:, setid:)
      results = []
      warn "evaluating #{subject} on #{setid}"
      set = get_sets(setid: setid)
      warn 'point 1', set.inspect
      return results if set.empty?

      _graphid, setdef = set.first
      setdef[:tests].each do |testid|
        test, *_nada = get_tests(testid: testid) # returns an array of 1 element, so just get that into test
        warn 'point 2', test.inspect
        _id, testdef = test.first # there is only one, and it is guid => {features...}
        warn 'point 3', testdef.inspect

        results << run_test(guid: subject, testapi: testdef['api'])
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(setid: "#{CHAMP_HOST}/sets/#{setid}", subject: subject)
      output.build_output(results: results) # returns jsonld
    end

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
        warn 'benchmark point 2', endpoint.inspect
        results << run_test(guid: subject, testapi: endpoint)
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(setid: bmid, subject: subject)
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
      # MUNGE IT TEMPORARILY!
      # the asesss/test should really consume the name of the test, not the shortname
      testname = if testapi.match(%r{.*/(\S+)/api})
                   testapi.match(%r{.*/(\S+)/api})[1]
                 else
                   testapi.match(%r{.*/(\S+)/?$})[1]
                 end
      testurl = "https://tests.ostrails.eu/assess/test/#{testname}"
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
    def get_tests(testid: '')
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

      results.select! { |res| res[:identifier] =~ /#{testid}/ } if testid

      results.map do |solution|
        solution.bindings.transform_values(&:to_s)
      end
      # warn alltests.to_json
    end
  end
end

# GROK
# require 'json'

# # Load the OpenAPI document
# openapi_json = File.read('openapi.json') # Replace with your file path
# openapi_data = JSON.parse(openapi_json)

# # Service name to match as part of the path (e.g., 'users')
# service_name = 'users'

# # Get the base URL (OpenAPI 3.x uses 'servers', OpenAPI 2.x uses 'host' and 'basePath')
# base_url = if openapi_data['servers'] # OpenAPI 3.x
#              openapi_data['servers'].first['url']
#            elsif openapi_data['host'] # OpenAPI 2.x
#              scheme = openapi_data['schemes']&.first || 'https'
#              base_path = openapi_data['basePath'] || ''
#              "#{scheme}://#{openapi_data['host']}#{base_path}"
#            else
#              raise "No base URL found in OpenAPI document"
#            end

# # Find PATCH paths where the service name is a component of the path
# patch_paths = openapi_data['paths'].flat_map do |path, methods|
#   if methods['patch'] && path.include?(service_name)
#     full_url = "#{base_url}#{path}"
#     { full_url: full_url, operation: methods['patch'] }
#   end
# end.compact

# # Output results
# if patch_paths.empty?
#   puts "No PATCH endpoints found matching '#{service_name}'"
# else
#   patch_paths.each do |match|
#     puts "Full URL: #{match[:full_url]}"
#     puts "Operation ID: #{match[:operation]['operationId'] || 'N/A'}"
#     puts "Tags: #{match[:operation]['tags']&.join(', ') || 'N/A'}"
#     puts "---"
#   end
# end

# ################################# SETS
# ########################################################################

# DEPRECATED
# def get_sets(setid: '')
#   setid = setid.to_sym if setid
#   url = CHAMPION_REPO

#   warn "SPARQL endpoint is #{url}"

#   client = SPARQL::Client.new(url)

#   schema = RDF::Vocab::SCHEMA
#   dc = RDF::Vocab::DC
#   _ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

#   setgraphquery = if setid.empty? # we want all graphs
#                     "select distinct ?g where {
#       GRAPH ?g {
#       ?s a <https://w3id.org/ftr#TestSetDefinition> .
#       }
#       }"
#                   else # we want one graph
#                     "select distinct ?g where {
#       GRAPH ?g {
#       <#{CHAMP_HOST}/sets/#{setid}> a <https://w3id.org/ftr#TestSetDefinition> .
#       }
#       }"
#                   end

#   r = client.query(setgraphquery)
#   graphs = r.map { |g| g[:g] } # get the id of each graph (representing each set) as a list

#   # we now have the desired graph URIs as a list... one or all
#   results = {}
#   graphs.each do |graph|
#     individualsetquery = "select distinct ?identifier ?name ?description ?creator ?part where {
#       GRAPH <#{graph}> {
#         ?s a <https://w3id.org/ftr#TestSetDefinition> .
#         ?s <#{schema.identifier}> ?identifier .
#         ?s <#{schema.name}> ?name .
#         ?s <#{schema.description}> ?description .
#         ?s <#{dc.creator}> ?creator .
#         ?s <#{schema.hasPart}> ?part .
#         }
#       }"
#     # warn 'set query', individualsetquery
#     r = client.query(individualsetquery)
#     # r contains duplicates of name desc creator, but multiple parts... get each part as a list
#     individualtests = []
#     title = description = creator = identifier = ''
#     r.each do |set|
#       identifier = set[:identifier]
#       title = set[:name]
#       description = set[:description]
#       creator = set[:creator]
#       individualtests << set[:part].to_s
#     end
#     results[graph.to_s] = {
#       identifier: identifier.to_s,
#       title: title.to_s,
#       description: description.to_s,
#       creator: creator.to_s,
#       tests: individualtests # individualtests is the LOCAL identifier, not the test API!
#     }
#   end
#   results
# end

# def add_set(title:, desc:, email:, tests:)
#   g = RDF::Repository.new
#   setid = _build_set_record(g: g, title: title, desc: desc, email: email, tests: tests)
#   newentry = g.dump(:nquads)
#   warn _write_set_to_graphdb(payload: newentry)
#   setid
# end

# def _build_set_record(g:, title:, desc:, email:, tests:)
#   schema = RDF::Vocab::SCHEMA
#   dc = RDF::Vocab::DC
#   ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

#   # contact = y['info']['contact']['email']
#   # org = y['info']['contact']['url']
#   id = Time.now.nsec
#   uniqueid = "#{CHAMP_HOST}/sets/#{id}"
#   context = "#{CHAMP_HOST}/sets/#{id}/context"

#   Champion::Output.triplify(uniqueid, RDF.type, ftr.TestSetDefinition, g, context: context)
#   Champion::Output.triplify(uniqueid, schema.identifier, uniqueid, g, context: context, datatype: 'xsd:string')
#   Champion::Output.triplify(uniqueid, schema.name, title, g, context: context)
#   Champion::Output.triplify(uniqueid, schema.description, desc, g, context: context)
#   Champion::Output.triplify(uniqueid, dc.creator, email, g, context: context, datatype: 'xsd:string')

#   tests.each do |test|
#     Champion::Output.triplify(uniqueid, schema.hasPart, test.to_s, g, context: context)
#   end
#   id
# end

# def _write_set_to_graphdb(payload:)
#   url = "#{CHAMPION_REPO}/statements"
#   headers = { content_type: 'application/n-quads', accept: '*/*' }

#   resp =  HTTPUtils.post(url: url, headers: headers, payload: payload, user: GRAPHDB_USER, pass: GRAPHDB_PASS)
#   warn "graphdb response #{resp}"
#   resp
# end
