module Champion
  class Test
    attr_accessor :identifier, :title, :name, :description, :endpoint, :openapi, :dimension, :objects, :domain,
                  :benchmark_or_metric

    def initialize(identifier:, title:, description:, endpoint: nil, openapi: nil,
                   dimension: nil, objects: nil, domain: nil, benchmark_or_metric: nil)
      @identifier = identifier
      @title = title
      @name = title # I can never remember whether I am using name or title, so just set them both to the same thing for now
      @description = description
      @endpoint = endpoint
      @openapi = openapi
      @dimension = dimension
      @objects = objects
      @domain = domain
      @benchmark_or_metric = benchmark_or_metric
    end
  end

  class TestResult
    attr_accessor :test_identifier, :title, :name, :description, :endpoint, :openapi, :dimension, :objects, :domain,
                  :benchmark_or_metric, :time, :value, :log, :suggestions, :completion, :graph, :rawjson, :execution, :target_resource

    def initialize(test_identifier:, title:, description:, time: nil, endpoint: nil, openapi: nil,
                   dimension: nil, objects: nil, domain: nil, benchmark_or_metric: nil,
                   value: nil, log: nil, suggestions: nil, execution: nil, completion: nil, target_resource: nil, rawjson: nil)
      @test_identifier = test_identifier
      @title = title
      @name = title # I can never remember whether I am using name or title, so             just set them both to the same thing for now
      @description = description
      @time = time
      @endpoint = endpoint
      @openapi = openapi
      @dimension = dimension
      @completion = completion
      @objects = objects
      @domain = domain
      @rawjson = rawjson
      @benchmark_or_metric = benchmark_or_metric
      @value = value
      @log = log
      @suggestions = suggestions
      @graph = RDF::Graph.new
      @execution = execution
      @target_resource = target_resource
    end

    def self.test_output_parser(output:)
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      prov = RDF::Vocab::PROV
      sio = RDF::Vocabulary.new('http://semanticscience.org/resource/')
      dcterms = RDF::Vocab::DC

      parsedgraph = RDF::Graph.new
      reader = RDF::Reader.for(:jsonld).new(StringIO.new(output))
      reader.each_statement { |stmt| parsedgraph << stmt }

      # Find the TestExecutionActivity
      query = RDF::Query.new do
        pattern [:testresult, RDF.type, ftr.TestResult]
        pattern [:testresult,   ftr.outputFromTest,     :test_uri]
        pattern [:test_uri,     dcterms.title,          :title]
        pattern [:test_uri,     dcterms.description,    :description]
        pattern [:testresult,   ftr.assessmentTarget,   :resource]
        pattern [:testresult,   prov.wasGeneratedBy,    :testactivity]
        pattern [:testresult,   ftr.log,                :log]
        pattern [:testresult,   prov.value,             :value]
        pattern [:testresult,   prov.generatedAtTime, :time]
        pattern [:testresult,   ftr.completion, :completion]
      end
      results = query.execute(parsedgraph)
      warn "RESULTS ARE #{results.inspect}"

      return output unless results.first

      r = results.first
      identifier = r[:test_uri]&.to_s
      title = r[:title]&.to_s
      description = r[:description]&.to_s

      testresult = Champion::TestResult.new(
        test_identifier: identifier,
        title: title,
        description: description
      )
      testresult.execution = r[:testactivity]&.to_s
      testresult.name = title
      testresult.graph = parsedgraph
      testresult.value = r[:value]&.to_s
      testresult.target_resource = r[:resource]&.to_s
      testresult.log = r[:log]&.to_s
      testresult.time = r[:time]&.to_s
      testresult.rawjson = output
      testresult.completion = r[:completion]&.to_s
      testresult
    end
  end
end
