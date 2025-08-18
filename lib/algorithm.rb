require 'rdf'
require 'rdf/ntriples'
require 'rdf/vocab'
require 'csv'
require 'rest-client'
require 'sparql/client'
require 'json'
require 'linkeddata'
require_relative 'dcat_extractor'

class Algorithm
  include RDF

  DCAT = RDF::Vocabulary.new('http://www.w3.org/ns/dcat#') # for some reason the built-in DCAT vocab doesnt recognize "version"
  FTR = RDF::Vocabulary.new('https://w3id.org/ftr#')
  VIVO = RDF::Vocabulary.new('http://vivoweb.org/ontology/core#')
  SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')
  DOAP = RDF::Vocab::DOAP
  VCARD = RDF::Vocab::VCARD
  DC = RDF::Vocab::DC
  # curl -v -L -H "content-type: application/json"
  # -d '{"clientUrl": "https://my.domain.org/path/to/DCAT/record.ttl"}'
  # https://tools.ostrails.eu/fdp-index-proxy/proxy
  FDPINDEXPROXY = ENV['FDPINDEXPROXY'] || 'https://tools.ostrails.eu/fdp-index-proxy/proxy'
  FDPSPARQL = ENV['FDPSPARQL'] || 'https://tools.ostrails.eu/repositories/fdpindex-fdp'

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
                 isImplementationOf:  SIO['SIO_000233'], # points to benchmark
                 scoringFunction: FTR.scoringFunction, # points to google sheet
                 contactPoint: DCAT.contactPoint
                }.freeze

  attr_accessor :calculation_uri, :baseURI, :csv, :algorithm_id, :algorithm_guid, :guid, :resultset, 
                :valid, :metadata, :graph, :tests,
                :conditions

  def initialize(calculation_uri:, baseURI: 'https://tools.ostrails.eu/champion', guid: nil, resultset: nil)
    @calculation_uri = calculation_uri
    @baseURI = baseURI
    @guid = guid
    @resultset = resultset
    @graph = RDF::Graph.new
    @metadata = {}
    @tests = []
    @conditions = []
    @valid = false
    # Must be a google docs template ands either a guid to test or the inut from another tools resultset
    @valid = true if @calculation_uri =~ %r{docs\.google\.com/spreadsheets} && (guid || resultset)
    # spreadsheets/d/  --> 16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
    @algorithm_id = @calculation_uri.match(%r{/spreadsheets/\w/([^/]+)})[1]
    @algorithm_guid = "#{@baseURI}/algorithms/#{algorithm_id}"
    # Transform the spreadsheet URL to CSV export format
    # https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w/edit?gid=0#gid=0
    calculation_uri = calculation_uri.sub(%r{/edit.*$}, '')
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

  # Prepare output data
  def process
    load_configuration
    test_results = resultset || run_tests
    narratives = evaluate_conditions(test_results)
    {
      metadata: metadata,
      test_results: test_results,
      narratives: narratives
    }
  end

  # Parse the Google Spreadsheet configuration
  def load_configuration
    gather_metadata

    empty_line_indices = csv.each_with_index.select { |line, _| line.strip.gsub(/,+/, '').empty? }.map(&:last)
    # Ensure we have at least two empty lines to separate three blocks
    if empty_line_indices.size < 2
      raise 'Invalid CSV structure: Expected at least two empty lines to separate three blocks'
    end

    @metadata['Assessed GUID'] = @guid

    c = Champion::Core.new

    test_csv = csv[(empty_line_indices[0] + 1)...empty_line_indices[1]].join
    csv_data = CSV.parse(test_csv, headers: true)
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

    # Parse conditions (remaining rows after empty row)
    # Parse conditions block (rows after second separator, with header)
    condition_csv = csv[(empty_line_indices[1] + 1)..-1].join
    csv_data = CSV.parse(condition_csv, headers: true)
    @conditions = csv_data.map do |row|
      {
        condition: row['Condition'],
        description: row['Description'],
        formula: row['Formula'],
        success: row['Success Message'],
        failure: row['Fail Message']
      }
    end

    # Store in RDF graph
    build_rdf_graph
  end

  def gather_metadata
    metadata = RDF::Graph.new
    # Find separator lines (containing only commas, whitespace, or empty after strip)
    empty_line_indices = csv.each_with_index.select { |line, _| line.strip.gsub(/,+/, '').empty? }.map(&:last)

    # Ensure we have at least two empty lines to separate three blocks
    if empty_line_indices.size < 2
      raise 'Invalid CSV structure: Expected at least two empty lines to separate three blocks'
    end

    # Parse metadata block (rows 0 to first empty line, with header)
    metadata_csv = csv[0...empty_line_indices[0]].join
    csv_data = CSV.parse(metadata_csv, headers: true)
    subject = RDF::URI.new("https://tools.ostrails.eu/champion/algorithms/#{algorithm_id}")
    csv_data.each do |row|
      # warn row.inspect
      # warn row["DCAT Property"]

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

    metadata << RDF::Statement.new(subject, RDF.type, FTR.ScoringAlgorithm)
    metadata << RDF::Statement.new(subject, RDF.type, DCAT.DataService)
    metadata << RDF::Statement.new(subject, DC.identifier, subject)

    endpoint = "#{baseURI}/assess/algorithm/#{algorithm_id}"
    metadata << RDF::Statement.new(subject, DCAT.endpointDescription, endpoint)
    metadata << RDF::Statement.new(subject, DCAT.endpointURL, endpoint)
    metadata << RDF::Statement.new(subject, FTR.scoringFunction, calculation_uri)
    metadata
  end

  def register  # initialize has already been called so all vars are full

    filename = "/tmp/#{algorithm_id}"  # I need to know this exactly one time, to create the metadata when the object is not yet registered!
    
    # Store the mapping in a file
    File.write(filename, {calculation_uri => algorithm_guid }.to_json)
    warn "Stored mapping"

    # curl -v -L -H "content-type: application/json"
    # -d '{"clientUrl": "https://my.domain.org/path/to/DCAT/record.ttl"}'
    # https://tools.ostrails.eu/fdp-index-proxy/proxy
    # FDPINDEXPROXY = ENV['FDPINDEXPROXY'] || "https://tools.ostrails.eu/fdp-index-proxy/proxy"
    # get '/champion/algorithms/:algorithm'

    warn "client url is #{algorithm_guid}"
    RestClient::Request.execute(
      method: :post,
      url: FDPINDEXPROXY,
      payload: { 'clientUrl' => algorithm_guid }.to_json,   # this needs to respond with DCAT, so I need to have access to the calculation_uri to generate that
      headers: { accept: 'application/json', content_type: 'application/json' },
      max_redirects: 10
    )
  end

  def self.retrieve_by_id(algorithm_id:)

    # Check if file exists
    # THE PROBLEM:  we cannot predict the Google Sheets URI, but we need it to create the object
    # so get it from the cache, or get it from the FDP Index
    if File.exist?("/tmp/#{algorithm_id}")  # this is the first time it has been called, so need to get calculation_uri from cache
      # Read and parse the mapping
      warn "RETRIEVING FROM CACHE"
      mapping = ::JSON.parse(File.read("/tmp/#{algorithm_id}"))
      calculation_uri, algorithm_guid = mapping.first

#      File.delete("/tmp/#{algorithm_id}") if File.exist?("/tmp/#{algorithm_id}")

      warn "Retrieved: #{calculation_uri}, #{algorithm_guid}"
      return calculation_uri
    else
      # if that temp mapping file doesn't exist, then the data is in the FDP registry, so we can get it from there... 
      query = <<EOQ
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dqv: <http://www.w3.org/ns/dqv#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <http://www.w3.org/ns/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT distinct ?identifier ?scoringfunction WHERE {
        ?subject a <https://w3id.org/ftr#ScoringAlgorithm> ;
          dct:identifier ?identifier ;
          ftr:scoringFunction ?scoringfunction .
          FILTER(CONTAINS(str(?identifier), "/champion/"))
          FILTER(CONTAINS(str(?identifier), "#{algorithm_id}"))
      } 
EOQ

warn "query is #{query}"
      endpoint = SPARQL::Client.new(FDPSPARQL)

      begin
        # Execute the query
        results = endpoint.query(query)
        warn "results:   #{results.inspect}"
        if results.first
          solution = results.first
          warn "solution:   #{solution.inspect}"

          return solution[:scoringfunction].to_s  # this is the calculation_uri requried to initialize the object
        else
          return false
        end
      end
    end
  end


  # Build RDF graph for semantic representation
  # not sure this is useful....??
  def build_rdf_graph
    algo = RDF::URI.new(@calculation_uri)
    @graph << [algo, RDF.type, RDF::URI.new('https://w3id.org/ftr#Algorithm')]
    @metadata.each do |key, value|
      @graph << [algo, RDF::URI.new("http://example.org/#{key}"), value]
    end

    @tests.each do |test|
      # reference: row['Test Reference'],
      # name: row['Test GUID'],
      # testid: row['Test GUID'],
      # endpoint: get_test_endpoint_for_testid(testid: row['Test GUID'])
      # pass_weight: row['Pass Weight'].to_f,
      # fail_weight: row['Fail Weight'].to_f,
      # indeterminate_weight: row['Indeterminate Weight'].to_f

      test_uri = RDF::URI.new(test[:testid])
      @graph << [test_uri, RDF.type, RDF::URI.new('http://example.org/Test')]
      @graph << [test_uri, RDF::URI.new('http://example.org/reference'), test[:reference]]
      @graph << [test_uri, RDF::URI.new('http://example.org/identifier'), test[:name]]
      @graph << [test_uri, RDF::URI.new('http://example.org/endpoint'), test[:endpoint]]
      @graph << [test_uri, RDF::URI.new('http://example.org/passWeight'), test[:pass_weight]]
      @graph << [test_uri, RDF::URI.new('http://example.org/failWeight'), test[:fail_weight]]
      @graph << [test_uri, RDF::URI.new('http://example.org/indeterminateWeight'), test[:indeterminate_weight]]
      @graph << [algo, RDF::URI.new('http://example.org/hasTest'), test_uri]
    end
  end

  # Run tests and collect results
  def run_tests
    endpoints = @tests.map { |test| test[:endpoint] }
    c = Champion::Core.new
    result_set = c.execute_on_endpoints(subject: @guid, endpoints: endpoints, bmid: @metadata['Benchmark GUID']) # ResultSet is the shared datastructure in the IF

    # warn "RESULT SET", result_set, "\n\n"
    results = {}
    @tests.each do |test|
      passfail = parse_single_test_response(result_set: result_set, testid: test[:name]) # extract result for THAT test from the restul-set
      results[test[:reference]] = {
        result: passfail,
        weight: case passfail
                when 'pass' then test[:pass_weight]
                when 'fail' then test[:fail_weight]
                when 'indeterminate' then test[:indeterminate_weight]
                else 0.0
                end
      }
    end
    results
  end

  # Stub for test response parsing (to be implemented in your existing codebase)
  def parse_single_test_response(result_set:, testid:)
    format = :jsonld
    graph = RDF::Graph.new
    graph << RDF::Reader.for(format).new(result_set)
    warn 'GRAPH:', graph.dump(:turtle), "\n\n"
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
    solutions = RDF::Query.execute(graph) do
      pattern [:execution, RDF.type, ftr.TestExecutionActivity]
      pattern [:execution, prov.generated, :result]
      pattern [:result, RDF.type, ftr.TestResult]
      pattern [:result, prov.value, :value]
    end
    warn "SOLUTIONS for <#{testid}>", solutions.inspect, "\n"

    passfail = solutions.map { |solution| solution[:value].to_s }.uniq
    if passfail.empty?
      raise "no score found for test #{testid}"
    elsif passfail.size > 1
      warn 'Warning: Multiple scores found.  Returning onlkh the first one.'
    end

    passfail.first
  end

  # Evaluate conditions and generate narratives
  def evaluate_conditions(test_results)
    # results[T1] = {
    #   result: "pass",
    #   weight: 10
    # } ...

    narratives = []
    @conditions.each do |condition|
      # {
      #   condition: row['Condition'],
      #   description: row['Description'],
      #   formula: row['Formula'],
      #   success: row['Success Message'],
      #   failure: row['Fail Message'],
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
        narratives << if is_met
                        (condition[:success] + ';')
                      else
                        (condition[:failure] + ';')
                      end
      rescue StandardError
        narratives << "Problem solving for #{formula}; "
      end
    end
    narratives
  end


  def self.list
    query = <<EOQ
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dqv: <http://www.w3.org/ns/dqv#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <http://www.w3.org/ns/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT distinct ?identifier ?title ?scoringfunction WHERE {
        ?subject a <https://w3id.org/ftr#ScoringAlgorithm> ;
          dct:identifier ?identifier ;
          dct:title ?title ;
          ftr:scoringFunction ?scoringfunction .
          FILTER(CONTAINS(str(?identifier), "/champion/"))
      } 
EOQ

    warn "query is #{query}"
    endpoint = SPARQL::Client.new(FDPSPARQL)
    list = {}
    begin
      # Execute the query
      results = endpoint.query(query)
      warn "results:   #{results.inspect}"

      results.each  do |solution|
        function = solution[:scoringfunction].to_s  # this is the calculation_uri requried to initialize the object
        title = solution[:title].to_s  # this is the calculation_uri requried to initialize the object
        identifier =  solution[:identifier].to_s  # this is the calculation_uri requried to initialize the object
        list[identifier] = [title, function]
      end
    end
    list
  end

end
