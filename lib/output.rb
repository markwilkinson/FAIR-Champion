module Champion
  class Output
    require 'cgi'
    require 'securerandom'
    require 'rdf/vocab'

    include RDF

    attr_accessor :subject, :setid, :description, :version, :license, :score, :title, :uniqueid

    def initialize(subject:, setid:, description: 'Results of the execution of test set', title: 'FAIR Champion output', version: '0.0.1', summary: 'Results of the execution of test set',
                   license: 'https://creativecommons.org/licenses/by/4.0/', score: '')
      @score = score
      @subject = subject
      @setid = setid
      @uniqueid = 'urn:fairchampionoutput:' + SecureRandom.uuid
      @title = title
      @description = description
      @license = license
      @dt = Time.now.iso8601
      @version = version
      @summary = "#{summary} #{setid}"
    end

    def build_output(results:)
      g = RDF::Graph.new
      schema = RDF::Vocab::SCHEMA
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      triplify(uniqueid, RDF.type, ftr.TestResultSet, g)
      triplify(uniqueid, RDF.type, RDF::Vocab::PROV.Collection, g)
      triplify(uniqueid, RDF.type, RDF::Vocab::PROV.Entity, g)
      triplify(uniqueid, schema.identifier, uniqueid, g)
      triplify(uniqueid, schema.name, title, g)
      triplify(uniqueid, schema.description, description, g)
      triplify(uniqueid, schema.license, license, g)

      authorid = 'urn:fairchampionauthor:' + SecureRandom.uuid
      triplify(uniqueid, RDF::Vocab::PROV.wasAttributedTo, authorid, g)
      triplify(uniqueid, schema.author, authorid, g)
      triplify(authorid, RDF.type, RDF::Vocab::PROV.Agent, g)
      contactid = 'urn:fairchampioncontact:' + SecureRandom.uuid
      triplify(authorid, schema.contactPoint, contactid, g)
      triplify(contactid, schema.url, 'https://wilkinsonlab.info', g)
      triplify(contactid, RDF.type, schema.ContactPoint, g)

      softwareid = 'urn:fairchampionsoftware:' + SecureRandom.uuid
      triplify(uniqueid, RDF::Vocab::PROV.wasAttributedTo, softwareid, g)
      triplify(softwareid, RDF.type, RDF::Vocab::PROV.SoftwareAgent, g)
      triplify(softwareid, RDF.type, schema.SoftwareApplication, g)
      triplify(softwareid, schema.softwareVersion, version, g)
      triplify(softwareid, schema.url, 'https://github.com/markwilkinson/FAIR-Champion', g)

      add_members(uniqueid: uniqueid, testoutputs: results, graph: g)

      tid = "urn:fairtestsetsubject:" + SecureRandom.uuid
      triplify(uniqueid, RDF::Vocab::PROV.wasDerivedFrom, tid, g)
      triplify(tid, RDF.type, RDF::Vocab::PROV.Entity, g)
      triplify(tid, schema.identifier, subject, g)
      triplify(tid, schema.url, subject, g) if subject =~ /^https?\:\/\//


      g.dump(:jsonld)
    end

    def add_members(uniqueid:, testoutputs:, graph:)
      testoutputs.each do |test|
        g = RDF::Graph.new
        data = StringIO.new(test.to_json)
        RDF::Reader.for(:jsonld).new(data) do |reader|
          reader.each_statement do |statement|
            warn statement.inspect
            g << statement  # this is only to query for the root id
            graph << statement  # this is the entire output graph
          end
        end
        q = SPARQL.parse('select distinct ?s where {?s a <https://w3id.org/ftr#TestResult>}')
        res = q.execute(g)
        testid = res.first[:s].to_s
        triplify(uniqueid, RDF::Vocab::PROV.hadMember, testid, graph)
      end
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
        o = if datatype
              RDF::Literal.new(o.to_s, datatype: datatype)
            elsif o.to_s =~ %r{\A\w+:/?/?\w[^\s]+}
              RDF::URI.new(o.to_s)
            elsif o.to_s =~ /^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d/
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.date)
            elsif o.to_s =~ /^[+-]?\d+\.\d+/ && o.to_s !~ /[^\+\-\d\.]/  # has to only be digits
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.float)
            elsif o.to_s =~ /^[+-]?[0-9]+$/ && o.to_s !~ /[^\+\-\d\.]/  # has to only be digits
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.int)
            else
              RDF::Literal.new(o.to_s, language: :en)
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
