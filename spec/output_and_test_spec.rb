require 'spec_helper'

RSpec.describe 'Champion output and test models' do
  def graph_jsonld(statements)
    graph = RDF::Graph.new
    statements.each { |statement| graph << statement }
    RDF::Writer.for(:jsonld).dump(graph)
  end

  def parsed_graph(jsonld)
    graph = RDF::Graph.new
    RDF::Reader.for(:jsonld).new(StringIO.new(jsonld)) do |reader|
      reader.each_statement { |statement| graph << statement }
    end
    graph
  end

  def test_result_hash(id: 'urn:testresult:1')
    {
      '@id' => id,
      '@type' => 'https://w3id.org/ftr#TestResult',
      'https://w3id.org/ftr#outputFromTest' => { '@id' => 'https://tests.example/test1' },
      'https://w3id.org/ftr#status' => 'pass'
    }
  end

  describe Champion::Output do
    let(:output) do
      described_class.new(
        subject: 'https://example.org/target',
        benchmarkid: 'https://example.org/benchmark',
        title: 'Output title',
        description: 'Output description',
        license: 'https://creativecommons.org/licenses/by/4.0/'
      )
    end

    it 'builds a JSON-LD test result set and links valid test result members' do
      jsonld = output.build_output(results: [test_result_hash])
      graph = parsed_graph(jsonld)
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')

      expect(graph.query([RDF::URI(output.uniqueid), RDF.type, ftr.TestResultSet]).count).to eq(1)
      expect(graph.query([RDF::URI(output.uniqueid), RDF::Vocab::PROV.hadMember, RDF::URI('urn:testresult:1')]).count).to eq(1)
      expect(graph.query([nil, ftr.assessmentTarget, nil]).count).to eq(1)
    end

    it 'adds an indeterminate error member when JSON-LD parsing fails' do
      graph = RDF::Graph.new

      output.add_members(
        uniqueid: output.uniqueid,
        testoutputs: [double('Unserializable output', to_json: '{"@id":')],
        graph: graph
      )

      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      error_result = graph.query([nil, RDF.type, ftr.TestResult]).first.subject

      expect(graph.query([RDF::URI(output.uniqueid), RDF::Vocab::PROV.hadMember, error_result]).count).to eq(1)
      expect(graph.query([error_result, ftr.status, RDF::Literal('indeterminate', language: :en)]).count).to eq(1)
      expect(graph.query([error_result, ftr.log, nil]).first.object.to_s).to include('JSON-LD parse failed')
    end

    it 'adds an indeterminate error member when output has no TestResult node' do
      graph = RDF::Graph.new

      output.add_members(
        uniqueid: output.uniqueid,
        testoutputs: [{ '@id' => 'urn:not-a-result', '@type' => 'https://example.org/Other' }],
        graph: graph
      )

      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      error_result = graph.query([nil, RDF.type, ftr.TestResult]).first.subject

      expect(graph.query([RDF::URI(output.uniqueid), RDF::Vocab::PROV.hadMember, error_result]).count).to eq(1)
      expect(graph.query([error_result, ftr.log, nil]).first.object.to_s).to include('no ftr:TestResult node')
    end

    it 'adds a standalone error stub' do
      graph = RDF::Graph.new

      output.add_error_stub(uniqueid: output.uniqueid, message: 'bad output', test: { bad: true }, graph: graph)

      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      error_result = graph.query([nil, RDF.type, ftr.TestResult]).first.subject
      expect(graph.query([error_result, ftr.log, nil]).first.object.to_s).to include('bad output')
      expect(graph.query([RDF::URI(output.uniqueid), RDF::Vocab::PROV.hadMember, error_result]).count).to eq(1)
    end

    describe '.triplify' do
      let(:repo) { RDF::Repository.new }
      let(:subject_uri) { 'urn:subject:1' }
      let(:predicate_uri) { 'https://example.org/predicate' }

      it 'returns false for empty inputs' do
        expect(described_class.triplify('', predicate_uri, 'value', repo)).to be(false)
        expect(described_class.triplify(subject_uri, '', 'value', repo)).to be(false)
        expect(described_class.triplify(subject_uri, predicate_uri, '', repo)).to be(false)
        expect(described_class.triplify(subject_uri, predicate_uri, 'value', nil)).to be(false)
      end

      it 'adds URI object statements' do
        expect(described_class.triplify(subject_uri, predicate_uri, 'https://example.org/object', repo)).to be(true)

        statement = repo.to_a.first
        expect(statement.subject).to eq(RDF::URI(subject_uri))
        expect(statement.predicate).to eq(RDF::URI(predicate_uri))
        expect(statement.object).to eq(RDF::URI('https://example.org/object'))
      end

      it 'adds explicit datatype literals' do
        described_class.triplify(subject_uri, predicate_uri, 'custom', repo, datatype: RDF::XSD.string)

        expect(repo.to_a.first.object).to be_literal
        expect(repo.to_a.first.object.datatype).to eq(RDF::XSD.string)
      end

      it 'infers date, float, integer, and English string literals' do
        described_class.triplify(subject_uri, predicate_uri, '2026-06-19T10:00:00Z', repo)
        described_class.triplify(subject_uri, predicate_uri, '10.5', repo)
        described_class.triplify(subject_uri, predicate_uri, '42', repo)
        described_class.triplify(subject_uri, predicate_uri, 'plain value', repo)

        objects = repo.map(&:object)
        expect(objects.map(&:datatype)).to include(RDF::XSD.date, RDF::XSD.float, RDF::XSD.int)
        expect(objects.last.language).to eq(:en)
      end

      it 'adds statements in a named graph context' do
        described_class.triplify(subject_uri, predicate_uri, 'value', repo, context: 'urn:graph:1')

        expect(repo.to_a.first.graph_name).to eq(RDF::URI('urn:graph:1'))
      end

      it 'aborts for non-URI-compatible subject, predicate, or context' do
        expect { described_class.triplify('not uri', predicate_uri, 'value', repo) }.to raise_error(SystemExit)
        expect { described_class.triplify(subject_uri, 'not uri', 'value', repo) }.to raise_error(SystemExit)
        expect { described_class.triplify(subject_uri, predicate_uri, 'value', repo, context: 'not uri') }.to raise_error(SystemExit)
      end
    end
  end

  describe Champion::Test do
    it 'stores metadata and mirrors title into name' do
      test = described_class.new(
        identifier: 'https://tests.example/test1',
        title: 'Metadata License',
        description: 'Checks license metadata',
        endpoint: 'https://tests.example/test1/api',
        openapi: 'https://tests.example/test1/openapi',
        dimension: 'findable',
        objects: ['Dataset'],
        domain: ['Biology'],
        benchmark_or_metric: 'https://example.org/metric'
      )

      expect(test).to have_attributes(
        identifier: 'https://tests.example/test1',
        title: 'Metadata License',
        name: 'Metadata License',
        description: 'Checks license metadata',
        endpoint: 'https://tests.example/test1/api',
        openapi: 'https://tests.example/test1/openapi',
        dimension: 'findable',
        objects: ['Dataset'],
        domain: ['Biology'],
        benchmark_or_metric: 'https://example.org/metric'
      )
    end
  end

  describe Champion::TestResult do
    it 'stores metadata, creates an empty graph, and mirrors title into name' do
      result = described_class.new(
        test_identifier: 'https://tests.example/test1',
        title: 'Metadata License',
        description: 'Checks license metadata',
        time: '2026-06-19T10:00:00Z',
        endpoint: 'https://tests.example/test1/api',
        openapi: 'https://tests.example/test1/openapi',
        dimension: 'findable',
        objects: ['Dataset'],
        domain: ['Biology'],
        benchmark_or_metric: 'https://example.org/metric',
        value: 'pass',
        log: 'ok',
        suggestions: 'none',
        execution: 'urn:execution:1',
        completion: '100',
        target_resource: 'https://example.org/target',
        rawjson: '{}'
      )

      expect(result).to have_attributes(
        test_identifier: 'https://tests.example/test1',
        title: 'Metadata License',
        name: 'Metadata License',
        description: 'Checks license metadata',
        value: 'pass',
        log: 'ok',
        suggestions: 'none',
        execution: 'urn:execution:1',
        completion: '100',
        target_resource: 'https://example.org/target',
        rawjson: '{}'
      )
      expect(result.graph).to be_a(RDF::Graph)
      expect(result.graph).to be_empty
    end

    it 'parses a JSON-LD test result into a TestResult object' do
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      prov = RDF::Vocab::PROV
      dcterms = RDF::Vocab::DC
      test_result = RDF::URI('urn:testresult:1')
      test_uri = RDF::URI('https://tests.example/test1')
      execution = RDF::URI('urn:execution:1')
      target = RDF::URI('https://example.org/target')
      jsonld = graph_jsonld([
                              [test_result, RDF.type, ftr.TestResult],
                              [test_result, ftr.outputFromTest, test_uri],
                              [test_uri, dcterms.title, 'Metadata License'],
                              [test_uri, dcterms.description, 'Checks license metadata'],
                              [test_result, ftr.assessmentTarget, target],
                              [test_result, prov.wasGeneratedBy, execution],
                              [test_result, ftr.log, 'ok'],
                              [test_result, prov.value, 'pass'],
                              [test_result, prov.generatedAtTime, '2026-06-19T10:00:00Z'],
                              [test_result, ftr.completion, '100']
                            ])

      result = described_class.test_output_parser(output: jsonld)

      expect(result).to be_a(described_class)
      expect(result).to have_attributes(
        test_identifier: 'https://tests.example/test1',
        title: 'Metadata License',
        name: 'Metadata License',
        description: 'Checks license metadata',
        execution: 'urn:execution:1',
        value: 'pass',
        target_resource: 'https://example.org/target',
        log: 'ok',
        time: '2026-06-19T10:00:00Z',
        rawjson: jsonld,
        completion: '100'
      )
      expect(result.graph).not_to be_empty
    end

    it 'returns the original output when no matching test result is present' do
      jsonld = graph_jsonld([[RDF::URI('urn:thing'), RDF.type, RDF::URI('https://example.org/Other')]])

      expect(described_class.test_output_parser(output: jsonld)).to eq(jsonld)
    end
  end
end
