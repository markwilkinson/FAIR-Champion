require 'rest_client'
require 'json'
require 'sparql'
require 'sparql/client'
require 'linkeddata'
require 'safe_yaml'
require 'rdf/nquads'

module Champion
  class Core
    attr_accessor :testhost, :champhost, :reponame, :graphdbhost


    def initialize; end

    # ################################# ASSESSMENTS
    # ########################################################################

    # CHECK WHAT IS SENT - IS IT THE FULL URI OF THE SET, OR JUST THE LOCAL IDENTIFIER
    # THEN RUN THE TEST.... Double check the API call in Routes!!!
    #  TODO TODO
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

        results << run_test(guid: subject, testurl: testdef['api'])
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(setid: "#{CHAMP_HOST}/sets/#{setid}", subject: subject)
      output.build_output(results: results)
    end

    def run_test(testurl:, guid:)
      warn "web call to #{testurl}"
      result = RestClient::Request.execute(
        url: testurl,
        method: :post,
        payload: { 'subject' => guid }.to_json,
        content_type: :json
      )
      JSON.parse(result.body)
    end

    # ################################# SETS
    # ########################################################################

    def get_sets(setid: '')
      setid = setid.to_sym if setid
      url = CHAMPION_REPO

      warn "SPARQL endpoint is #{url}"

      client = SPARQL::Client.new(url)

      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      _ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      setgraphquery = if setid.empty? # we want all graphs
                        "select distinct ?g where {
          GRAPH ?g {
          ?s a <https://w3id.org/ftr#TestSetDefinition> .
          }
          }"
                      else # we want one graph
                        "select distinct ?g where {
          GRAPH ?g {
          <#{CHAMP_HOST}/sets/#{setid}> a <https://w3id.org/ftr#TestSetDefinition> .
          }
          }"
                      end

      r = client.query(setgraphquery)
      graphs = r.map { |g| g[:g] } # get the id of each graph (representing each set) as a list

      # we now have the desired graph URIs as a list... one or all
      results = {}
      graphs.each do |graph|
        individualsetquery = "select distinct ?identifier ?name ?description ?creator ?part where {
          GRAPH <#{graph}> {
            ?s a <https://w3id.org/ftr#TestSetDefinition> .
            ?s <#{schema.identifier}> ?identifier .
            ?s <#{schema.name}> ?name .
            ?s <#{schema.description}> ?description .
            ?s <#{dc.creator}> ?creator .
            ?s <#{schema.hasPart}> ?part .
            }
          }"
        # warn 'set query', individualsetquery
        r = client.query(individualsetquery)
        # r contains duplicates of name desc creator, but multiple parts... get each part as a list
        individualtests = []
        title = description = creator = identifier = ''
        r.each do |set|
          identifier = set[:identifier]
          title = set[:name]
          description = set[:description]
          creator = set[:creator]
          individualtests << set[:part].to_s
        end
        results[graph.to_s] = {
          identifier: identifier.to_s,
          title: title.to_s,
          description: description.to_s,
          creator: creator.to_s,
          tests: individualtests # individualtests is the LOCAL identifier, not the test API!
        }
      end
      results
    end

    def add_set(title:, desc:, email:, tests:)
      g = RDF::Repository.new
      setid = _build_set_record(g: g, title: title, desc: desc, email: email, tests: tests)
      newentry = g.dump(:nquads)
      warn _write_set_to_graphdb(payload: newentry)
      setid
    end

    def _build_set_record(g:, title:, desc:, email:, tests:)
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      # contact = y['info']['contact']['email']
      # org = y['info']['contact']['url']
      id = Time.now.nsec
      uniqueid = "#{CHAMP_HOST}/sets/#{id}"
      context = "#{CHAMP_HOST}/sets/#{id}/context"

      Champion::Output.triplify(uniqueid, RDF.type, ftr.TestSetDefinition, g, context: context)
      Champion::Output.triplify(uniqueid, schema.identifier, uniqueid, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, schema.name, title, g, context: context)
      Champion::Output.triplify(uniqueid, schema.description, desc, g, context: context)
      Champion::Output.triplify(uniqueid, dc.creator, email, g, context: context, datatype: 'xsd:string')

      tests.each do |test|
        Champion::Output.triplify(uniqueid, schema.hasPart, test.to_s, g, context: context)
      end
      id
    end

    def _write_set_to_graphdb(payload:)
      url = "#{CHAMPION_REPO}/statements"
      headers = { content_type: 'application/n-quads', accept: '*/*' }

      resp =  HTTPUtils.post(url: url, headers: headers, payload: payload, user: GRAPHDB_USER, pass: GRAPHDB_PASS)
      warn "graphdb response #{resp}"
      resp
    end

    # ##############################################################
    #     TESTS
    # ##############################################################

    def get_tests(testid: '')
      warn 'IN GET TESTS'
      testid = testid.to_s.gsub(%r{.*/}, '') # if we are sent the entire URI, then just take the identifier part at the end

      schema = RDF::Vocab::SCHEMA
      _dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      sparqlurl = CHAMPION_REPO

      client = SPARQL::Client.new(sparqlurl)
      # every service is a named graph
      sparql = if testid.empty?
                 "select distinct ?g ?s ?title ?description where {
          GRAPH ?g {
            ?s a <#{ftr.TestDefinition}> .
            ?s <#{schema.name}> ?title .
            ?s <#{schema.description}> ?description .
        }
        }"
               else
                 "select distinct ?g ?s ?title ?description where {
          GRAPH ?g {
            VALUES ?s {<#{CHAMP_HOST}/tests/#{testid}>}
            ?s a <#{ftr.TestDefinition}> .
            ?s <#{schema.name}> ?title .
            ?s <#{schema.description}> ?description .
          }
          }"
               end
      # warn 'SPARQL', sparql, "\n"
      result = client.query(sparql)
      # warn 'RESULT', result.inspect
      result.map do |r|
        { r[:s].to_s => { 'api' => r[:g].to_s, 'title' => r[:title].to_s, 'description' => r[:description].to_s } }
      end
    end

    def add_test(api:)
      SafeYAML::OPTIONS[:default_mode] = :safe
      g = RDF::Repository.new

      result = HTTPUtils.get(
        url: api
      )
      y = YAML.safe_load(result)
      testid = _build_test_record(yaml: y, graph: g, context: api)
      newentry = g.dump(:nquads)
      _write_test_to_graphdb(payload: newentry)
      testid
    end

    def _build_test_record(yaml:, graph:, context:)
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      title = yaml['info']['title']
      description = yaml['info']['description']
      version = yaml['info']['version']
      contact = yaml['info']['contact']['email']
      org = yaml['info']['contact']['url']
      testid = Time.now.nsec

      uniqueid = "#{CHAMP_HOST}/tests/#{testid}"
      Champion::Output.triplify(uniqueid, RDF.type, ftr.TestDefinition, graph, context: context)
      Champion::Output.triplify(uniqueid, schema.identifier, context, graph, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, schema.name, title, graph, context: context)
      Champion::Output.triplify(uniqueid, schema.description, description, graph, context: context)
      Champion::Output.triplify(uniqueid, schema.version, version, graph, context: context)
      Champion::Output.triplify(uniqueid, dc.creator, contact, graph, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, dc.creator, org, graph, context: context, datatype: 'xsd:string')
      testid
    end

    def _write_test_to_graphdb(payload:)
      url = "#{CHAMPION_REPO}/statements"
      headers = { content_type: 'application/n-quads', accept: '*/*' }
      resp =  HTTPUtils.post(url: url, headers: headers, payload: payload, user: GRAPHDB_USER, pass: GRAPHDB_PASS)
      warn "graphdb response #{resp}"
      resp
    end


    # ##############################################################
    #     BENCHMARK
    # ##############################################################

    def get_benchmark(bmid: '')
      warn 'IN GET BENCHMARKS'
      
    end

  end
end
