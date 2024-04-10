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

    def initialize
      # @testhost = "http://tests:4567/tests/"
      @testhost = ENV.fetch('TESTHOST', nil)
      # @testhost = 'http://fairdata.services:8282/tests/'
      @champhost = ENV.fetch('CHAMPHOST', nil)
      @graphdbhost = ENV.fetch('GRAPHDBNAME', "graphdb")
      # @champhost = 'http://fairdata.systems:8383'
      # @champhost = 'http://localhost:4567/'
      @testhost = @testhost.gsub(%r{/+$}, '')
      @champhost = @champhost.gsub(%r{/+$}, '')
      @reponame = ENV.fetch('CHAMPDB',"champion")
#      @sets = get_sets  # TODO  is this still necessary??
    end


    # ################################# ASSESSMENTS 
    # ########################################################################

    # CHECK WHAT IS SENT - IS IT THE FULL URI OF THE SET, OR JUST THE LOCAL IDENTIFIER
    # THEN RUN THE TEST.... Double check the API call in Routes!!!
    #  TODO TODO
    def run_assessment(subject:, setid:)
      warn "evaluating #{subject} on #{setid}"
      set = get_sets(setid: setid)
      # results[graph.to_s] = {
      #   identifier: identifier.to_s, 
      #   title: title.to_s, 
      #   description: description.to_s, 
      #   creator: creator.to_s, 
      #   tests: individualtests}
      results = []
      set[:tests].each do |testurl|
        results << run_test(guid: subject, testurl: testurl)
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(setid: "#{champhost}/sets/#{setid}", subject: subject)
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

    def get_sets(setid: nil)
      setid = setid.to_sym if setid
      url = "http://#{graphdbhost}:7200/repositories/#{reponame}"

      warn "SPARQL endpoint is #{url}"

      client = SPARQL::Client.new(url)

      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      if setid  # we want one graph
        setgraphquery = "select distinct ?g where { 
          GRAPH ?g {
          <#{champhost}/sets/#{setid}> a <https://w3id.org/ftr#TestSetDefinition> .
          }
          }"
      else  # we want all graphs
        setgraphquery = "select distinct ?g where { 
          GRAPH ?g {
          ?s a <https://w3id.org/ftr#TestSetDefinition> .
          }
          }"
      end

      r = client.query(setgraphquery)
      graphs = r.map {|g| g[:g]}  # get the id of each graph (representing each set) as a list

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
        r = client.query(individualsetquery)
        # r contains duplicates of name desc creator, but multiple parts... get each part as a list
        individualtests = []
        title = description = creator = identifier = ""
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
          tests: individualtests}
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

    def _build_set_record(g:, title: , desc: , email: , tests:  )
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      # contact = y['info']['contact']['email']
      # org = y['info']['contact']['url']
      id = Time.now.nsec
      uniqueid = "#{champhost}/sets/#{id}"
      context = "#{champhost}/sets/#{id}/context"

      Champion::Output.triplify(uniqueid, RDF.type, ftr.TestSetDefinition, g, context: context)
      Champion::Output.triplify(uniqueid, schema.identifier, uniqueid, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, schema.name, title, g, context: context)
      Champion::Output.triplify(uniqueid, schema.description, desc, g, context: context)
      Champion::Output.triplify(uniqueid, dc.creator, email, g, context: context, datatype: 'xsd:string')

      tests.each do |test|
        Champion::Output.triplify(uniqueid, schema.hasPart, test.to_s, g, context: context,)
      end
      id
    end

    def _write_set_to_graphdb(payload:)
      user = ENV.fetch('GraphDB_User', "champion")
      pass = ENV.fetch('GraphDB_Pass', "champion")
      graphdbhostname = ENV.fetch('graphdbnetworkname', 'graphdb')
      reponame = ENV.fetch('GRAPHDB_REPONAME', "champion")
      url = "http://#{graphdbhostname}:7200/repositories/#{reponame}/statements"
      headers = { content_type: 'application/n-quads', accept: "*/*" }

      resp =  HTTPUtils.post(url: url, headers: headers, payload: payload, user: user, pass: pass) 
      warn "graphdb response #{resp}"
      resp
    end


    # ##############################################################
    # ##############################################################

    def get_tests(testid: nil)
      warn "IN GET TESTS"
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      user = ENV.fetch('GraphDB_User', "champion")
      pass = ENV.fetch('GraphDB_Pass', "champion")
      hostname = ENV.fetch('networkname', 'graphdb')
      reponame = ENV.fetch('GRAPHDB_REPONAME', "champion")
      url = "http://#{hostname}:7200/repositories/#{reponame}"

      client = SPARQL::Client.new(url)
      # every service is a named graph
      if testid
        sparql = "select distinct ?g ?s ?title ?description where { 
          GRAPH ?g {
            VALUES ?s {<#{champhost}/tests/#{testid}>}
            ?s a <#{ftr.TestDefinition}> .
            ?s <#{schema.name}> ?title .
            ?s <#{schema.description}> ?description .
          }
          }"
      else 
        sparql = "select distinct ?g ?s ?title ?description where { 
          GRAPH ?g {
            ?s a <#{ftr.TestDefinition}> .
            ?s <#{schema.name}> ?title .
            ?s <#{schema.description}> ?description .
        }
        }"
      end
      warn "SPARQL", sparql, "\n"
      result = client.query(sparql)
      result.map {|r| {r[:s].to_s => {"guid" => r[:g].to_s, "title" => r[:title].to_s, "description" => r[:description].to_s}}}
    end

    def add_test(api:)
      SafeYAML::OPTIONS[:default_mode] = :safe
      g = RDF::Repository.new

      result = HTTPUtils.get(
        url: api
      )
      y = YAML.safe_load(result)
      _build_test_record(y: y, g: g, context: api)
     newentry = g.dump(:nquads)
     _write_test_to_graphdb(payload: newentry)
    end

    def _build_test_record(y:, g:, context: )
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      title = y['info']['title']
      description = y['info']['description']
      version = y['info']['version']
      contact = y['info']['contact']['email']
      org = y['info']['contact']['url']

      uniqueid = "#{champhost}/tests/#{Time.now.nsec}"
      Champion::Output.triplify(uniqueid, RDF.type, ftr.TestDefinition, g, context: context)
      Champion::Output.triplify(uniqueid, schema.identifier, context, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, schema.name, title, g, context: context)
      Champion::Output.triplify(uniqueid, schema.description, description, g, context: context)
      Champion::Output.triplify(uniqueid, schema.version, version, g, context: context)
      Champion::Output.triplify(uniqueid, dc.creator, contact, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, dc.creator, org, g, context: context, datatype: 'xsd:string')
    end

    def _write_test_to_graphdb(payload:)
      user = ENV.fetch('GraphDB_User', "champion")
      pass = ENV.fetch('GraphDB_Pass', "champion")
      hostname = ENV.fetch('networkname', 'graphdb')
      reponame = ENV.fetch('GRAPHDB_REPONAME', "champion")
      url = "http://#{hostname}:7200/repositories/#{reponame}/statements"
      headers = { content_type: 'application/n-quads', accept: "*/*" }

      resp =  HTTPUtils.post(url: url, headers: headers, payload: payload, user: user, pass: pass) 
      warn "graphdb response #{resp}"
      resp
    end

  end
end
