require 'rest_client'
require 'json'
require 'sparql'
require 'sparql/client'
require 'linkeddata'
require 'safe_yaml'
require 'rdf/nquads'

module Champion
  class Core
    attr_accessor :sets, :testhost, :champhost

    def initialize
      # @testhost = "http://tests:4567/tests/"
      @testhost = ENV.fetch('TESTHOST', nil)
      # @testhost = 'http://fairdata.services:8282/tests/'
      @champhost = ENV.fetch('CHAMPHOST', nil)
      # @champhost = 'http://fairdata.systems:8383'
      # @champhost = 'http://localhost:4567/'
      @testhost = @testhost.gsub(%r{/+$}, '')
      @champhost = @champhost.gsub(%r{/+$}, '')
      @sets = get_sets
    end

    def run_evaluation(subject:, setid:)
      warn "evaluating #{subject} on #{setid}"
      setid = setid.to_sym
      results = []
      sets[setid].each do |testurl|
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

    def get_sets(setid: nil)
      setid = setid.to_sym if setid

      # Dir.entries("../cache/*.json")
      # g = RDF::Graph.new

      warn "set requested #{setid}"
      sets = { OSTrails1: [
        "#{testhost}/fc_data_authorization",
        "#{testhost}/fc_data_identifier_in_metadata",
        "#{testhost}/fc_data_kr_language_strong",
        "#{testhost}/fc_data_kr_language_weak",
        "#{testhost}/fc_data_protocol",
        "#{testhost}/fc_metadata_persistence",
        "#{testhost}/fc_metadata_protocol",
        "#{testhost}/fc_unique_identifier"
      ] }
      return sets[setid] if setid

      sets
    end

    def add_set(title:, desc:, email:, tests:)
      g = RDF::Repository.new
      _build_set_record(title: title, desc: desc, email: email, tests: tests)
     newentry = g.dump(:nquads)
     _write_set_to_graphdb(payload: newentry)
    end

    def _build_set_record(title: , desc: , email: , tests:  )
      schema = RDF::Vocab::SCHEMA
      dc = RDF::Vocab::DC
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      contact = y['info']['contact']['email']
      org = y['info']['contact']['url']
      context = ......................

      uniqueid = "#{champhost}/sets/#{Time.now.nsec}"
      Champion::Output.triplify(uniqueid, RDF.type, ftr.TestSetDefinition, g, context: context)
      Champion::Output.triplify(uniqueid, schema.identifier, context, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, schema.name, title, g, context: context)
      Champion::Output.triplify(uniqueid, schema.description, description, g, context: context)
      Champion::Output.triplify(uniqueid, schema.version, version, g, context: context)
      Champion::Output.triplify(uniqueid, dc.creator, contact, g, context: context, datatype: 'xsd:string')
      Champion::Output.triplify(uniqueid, dc.creator, org, g, context: context, datatype: 'xsd:string')
    end

    def _write_set_to_graphdb(payload:)
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


    # ##############################################################
    # ##############################################################

    def get_tests(testid: nil)
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
