require 'rdf'
require 'rdf/ntriples'
require 'csv'
require 'rest-client'
require 'json'
require 'linkeddata'
require_relative './dcat_extractor.rb'

class Algorithm
  include RDF

  def initialize(calculation_uri, guid)
    @calculation_uri = calculation_uri
    @guid = guid
    @graph = RDF::Graph.new
    @metadata = {}
    @tests = []
    @conditions = []
  end

    # Prepare output data
  def process
    load_configuration
    test_results = run_tests
    narratives = evaluate_conditions(test_results)
    {
      metadata: @metadata,
      test_results: test_results,
      narratives: narratives
    }
  end

  # Parse the Google Spreadsheet configuration
  def load_configuration
    # Transform the spreadsheet URL to CSV export format
    csv_url = @calculation_uri.sub(/\/edit.*$/, '') + '/export?exportFormat=csv'
    # Use RestClient with follow redirects (default max_redirects is 10)
    response = RestClient::Request.execute(
      method: :get,
      url: csv_url,
      headers: { accept: 'text/csv' },
      max_redirects: 10
    )
    
    # Split CSV into lines to identify blocks
    csv_lines = response.body.lines
    # Find separator lines (containing only commas, whitespace, or empty after strip)
    empty_line_indices = csv_lines.each_with_index.select { |line, _| line.strip.gsub(/,+/, '').empty? }.map(&:last)

    # Ensure we have at least two empty lines to separate three blocks
    raise "Invalid CSV structure: Expected at least two empty lines to separate three blocks" if empty_line_indices.size < 2
    @metadata = {}
    # Parse metadata block (rows 0 to first empty line, with header)
    metadata_csv = csv_lines[0...empty_line_indices[0]].join
    csv_data = CSV.parse(metadata_csv, headers: true)
    @metadata = csv_data.each_with_object({}) do |row, hash|
      hash[row['Property']] = row['Value']
    end

    c = Champion::Core.new

    test_csv = csv_lines[(empty_line_indices[0] + 1)...empty_line_indices[1]].join
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
  condition_csv = csv_lines[(empty_line_indices[1] + 1)..-1].join
  csv_data = CSV.parse(condition_csv, headers: true)
  @conditions = csv_data.map do |row|
      {
        condition: row['Condition'],
        description: row['Description'],
        formula: row['Formula'],
        success: row['Success Message'],
        failure: row['Fail Message'],
      }
    end

    # Store in RDF graph
    build_rdf_graph
  end

  # Build RDF graph for semantic representation
  # not sure this is useful....??
  def build_rdf_graph
    algo = RDF::URI.new(@calculation_uri)
    @graph << [algo, RDF.type, RDF::URI.new("https://w3id.org/ftr#Algorithm")]
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
      @graph << [test_uri, RDF.type, RDF::URI.new("http://example.org/Test")]
      @graph << [test_uri, RDF::URI.new("http://example.org/reference"), test[:reference]]
      @graph << [test_uri, RDF::URI.new("http://example.org/identifier"), test[:name]]
      @graph << [test_uri, RDF::URI.new("http://example.org/endpoint"), test[:endpoint]]
      @graph << [test_uri, RDF::URI.new("http://example.org/passWeight"), test[:pass_weight]]
      @graph << [test_uri, RDF::URI.new("http://example.org/failWeight"), test[:fail_weight]]
      @graph << [test_uri, RDF::URI.new("http://example.org/indeterminateWeight"), test[:indeterminate_weight]]
      @graph << [algo, RDF::URI.new("http://example.org/hasTest"), test_uri]
    end
  end

  # Run tests and collect results
  def run_tests
    endpoints = @tests.map {|test| test[:endpoint]}
    c = Champion::Core.new
    result_set = c.execute_on_endpoints(subject: @guid, endpoints: endpoints, bmid: @metadata["Benchmark GUID"]) # ResultSet is the shared datastructure in the IF

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
    format = "jsonld"
    graph = RDF::Graph.new << RDF::Reader.for(format).new(result_set)

# <urn:ostrails:testexecutionactivity:42c79dfe-fc9a-40db-84b6-6a3e69b8afab> a <https://w3id.org/ftr#TestExecutionActivity>;
#   prov:generated <urn:fairtestoutput:2152d30f-516c-43da-b647-4f4726c33fbb>;
#   prov:used <https://w3id.org/duchenne-fdp>;
#   prov:wasAssociatedWith <https://tests.ostrails.eu/tests/fc_metadata_includes_license> .
# <urn:fairtestoutput:2152d30f-516c-43da-b647-4f4726c33fbb> a <https://w3id.org/ftr#TestResult>;
#   prov:value "pass"@en;

    dcat = RDF::Vocab::DCAT
    prov = RDF::Vocab::PROV
    ftr = RDF::Vocab.new("https://w3id.org/ftr")
    solutions = RDF::Query.execute(graph) do
      pattern [:execution, RDF.type, ftr.TestExecutionActivity]
      pattern [:execution, prov.wasAssociatedWith, "<#{testid}>"]
      pattern [:execution, prov.generated, :result]
      pattern [:result, RDF.type, ftr.TestResult]
      pattern [:result, prov.value, :value]
    end

    passfail = solutions.map { |solution| solution[:value].to_s }.uniq
    if passfail.empty?
      raise "no score found for test #{testid}"
    elsif passfail.size > 1
      puts "Warning: Multiple scores found.  Returning onlkh the first one."
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
        if is_met
          narratives << condition[:success] + ";"
        else
          narratives << condition[:failure] + ";"
        end
      rescue StandardError => e
        narratives << "Problem solving for #{formula}; "
      end
    end
    narratives
  end

end