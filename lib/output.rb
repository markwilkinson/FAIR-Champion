module Champion
  class Output

    require 'cgi'
    require 'securerandom'
    require "rdf/vocab"

    include RDF

    attr_accessor :guid, :setid, :description, :version, :summary, :license, :score, :name
    @@comments = []

    def initialize(guid:, setid:, description: "", name: "FAIR Champion output", version: "0.0.1", summary: "Summary", license: "https://creativecommons.org/licenses/by/4.0/", score: "")
      @score = score
      @guid = guid
      @guid = setid
      @uniqueid = "urn:fairchampionoutput:" + SecureRandom.uuid
      @name = name
      @description = description
      @license = license
      @dt = Time.now.iso8601
      @version = version
      @summary = summary

    end
    

    def build_output(results:)
      g = RDF::Graph.new
      schema = RDF::Vocab::SCHEMA
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      add_newline_to_comments

      if summary =~ /^Summary$/
        summary = "Summary of test results: #{@@comments[-1]}"
        summary = "Summary of test results: #{@@comments[-2]}" unless summary
      end


      triplify(uniqueid, RDF.type, ftr.TestResult, g)
      triplify(uniqueid, schema.identifier, uniqueid, g)
      triplify(uniqueid, schema.name, name, g)
      triplify(uniqueid, schema.version, version, g)
      triplify(uniqueid, schema.description, description, g)
      triplify(uniqueid, schema.license, license, g)
      triplify(uniqueid, ftr.status, score, g)
      triplify(uniqueid, ftr.summary, summary, g)
      triplify(uniqueid, RDF::Vocab::PROV.generatedAtTime, dt, g)
      triplify(uniqueid, ftr.log, @@comments.join, g)
      triplify(uniqueid, ftr.completion, completeness, g)
      triplify(uniqueid, ftr.definedBy, metric, g)
      triplify(metric, RDF.type, ftr.TestSpecification, g)
      

      tid = "urn:fairtestentity:" + SecureRandom.uuid
      triplify(uniqueid, RDF::Vocab::PROV.wasDerivedFrom, tid, g)
      triplify(tid, RDF.type, RDF::Vocab::PROV.Entity, g)
      triplify(tid, schema.identifier, testedGUID, g)
      triplify(tid, schema.url, testedGUID, g) if testedGUID =~ /^https?\:\/\//
      

      g.dump(:jsonld)
    end

    # can be called as FAIRChampion::Output.comments << "newcomment"
    def self.comments
      @@comments
    end
    def comments
      @@comments
    end
    def self.clear_comments
      @@comments = []
    end
    def add_newline_to_comments
      cleancomments = []
      @@comments.each do |c|
        c += "\n" unless c =~ /\n$/
        cleancomments << c
      end
      @@comments = cleancomments
    end


    def triplify(s, p, o, repo, datatype = nil)
      s = s.strip if s.instance_of?(String)
      p = p.strip if p.instance_of?(String)
      o = o.strip if o.instance_of?(String)

      unless s.respond_to?('uri')

        if s.to_s =~ %r{^\w+:/?/?[^\s]+}
          s = RDF::URI.new(s.to_s)
        else
          abort "Subject #{s} must be a URI-compatible thingy"
        end
      end

      unless p.respond_to?('uri')

        if p.to_s =~ %r{^\w+:/?/?[^\s]+}
          p = RDF::URI.new(p.to_s)
        else
          abort "Predicate #{p} must be a URI-compatible thingy"
        end
      end

      unless o.respond_to?('uri')
        if datatype
          o = RDF::Literal.new(o.to_s, datatype: datatype)
        else
          if o.to_s =~ %r{\A\w+:/?/?\w[^\s]+}
            o = RDF::URI.new(o.to_s)
          elsif o.to_s =~ /^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d/
            o = RDF::Literal.new(o.to_s, datatype: RDF::XSD.date)
          elsif o.to_s =~ /^[+-]?\d+\.\d+/ && o.to_s !~ /[^\+\-\d\.]/  # has to only be digits
            o = RDF::Literal.new(o.to_s, datatype: RDF::XSD.float)
          elsif o.to_s =~ /^[+-]?[0-9]+$/ && o.to_s !~ /[^\+\-\d\.]/  # has to only be digits
            o = RDF::Literal.new(o.to_s, datatype: RDF::XSD.int)
          else
            o = RDF::Literal.new(o.to_s, language: :en)
          end
        end
      end

      triple = RDF::Statement(s, p, o)
      repo.insert(triple)

      true
    end

    def self.triplify(s, p, o, repo)
      triplify(s, p, o, repo)
    end


  end
end
