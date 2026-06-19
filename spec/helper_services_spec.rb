require 'spec_helper'

RSpec.describe 'helper service utilities' do
  class HTTPUtilsSpecRestClientException < RestClient::Exception
    attr_reader :response

    def initialize(response)
      @response = response
      super()
    end
  end

  describe HTTPUtils do
    let(:response) { double('Response', body: 'ok') }
    let(:error_response) { double('Error response', code: 500, body: 'error') }

    describe '.get' do
      it 'executes a GET request with credentials and headers' do
        request = instance_double('RestClient::Request', execute: response)
        allow(RestClient::Request).to receive(:new).and_return(request)

        expect(described_class.get(url: 'https://example.org/data', headers: { accept: 'text/turtle' },
                                   user: 'alice', pass: 'secret')).to eq(response)
        expect(RestClient::Request).to have_received(:new).with(
          method: :get,
          url: 'https://example.org/data',
          user: 'alice',
          password: 'secret',
          headers: { accept: 'text/turtle' }
        )
      end

      it 'returns false for HTTP response exceptions' do
        request = instance_double('RestClient::Request')
        allow(request).to receive(:execute).and_raise(RestClient::ExceptionWithResponse.new(error_response))
        allow(RestClient::Request).to receive(:new).and_return(request)

        expect(described_class.get(url: 'https://example.org/data')).to be(false)
      end

      it 'returns false for RestClient exceptions without response bodies' do
        request = instance_double('RestClient::Request')
        allow(request).to receive(:execute).and_raise(HTTPUtilsSpecRestClientException.new(error_response))
        allow(RestClient::Request).to receive(:new).and_return(request)

        expect(described_class.get(url: 'https://example.org/data')).to be(false)
      end

      it 'returns false for unexpected exceptions' do
        request = instance_double('RestClient::Request')
        allow(request).to receive(:execute).and_raise(RuntimeError, 'boom')
        allow(RestClient::Request).to receive(:new).and_return(request)

        expect(described_class.get(url: 'https://example.org/data')).to be(false)
      end
    end

    shared_examples 'a mutating HTTP verb wrapper' do |method_name, http_method|
      it "executes a #{http_method.upcase} request" do
        allow(RestClient::Request).to receive(:execute).and_return(response)

        expect(described_class.public_send(method_name, url: 'https://example.org/data',
                                                        payload: '{"ok":true}',
                                                        headers: { accept: 'application/json' },
                                                        user: 'alice',
                                                        pass: 'secret')).to eq(response)
        expect(RestClient::Request).to have_received(:execute).with(
          method: http_method,
          url: 'https://example.org/data',
          user: 'alice',
          password: 'secret',
          payload: '{"ok":true}',
          headers: { accept: 'application/json' }
        )
      end

      it "returns false when #{http_method.upcase} receives an HTTP response exception" do
        allow(RestClient::Request).to receive(:execute)
          .and_raise(RestClient::ExceptionWithResponse.new(error_response))

        expect(described_class.public_send(method_name, url: 'https://example.org/data', payload: '{}')).to be(false)
      end

      it "returns false when #{http_method.upcase} receives another RestClient exception" do
        allow(RestClient::Request).to receive(:execute)
          .and_raise(HTTPUtilsSpecRestClientException.new(error_response))

        expect(described_class.public_send(method_name, url: 'https://example.org/data', payload: '{}')).to be(false)
      end

      it "returns false when #{http_method.upcase} raises unexpectedly" do
        allow(RestClient::Request).to receive(:execute).and_raise(RuntimeError, 'boom')

        expect(described_class.public_send(method_name, url: 'https://example.org/data', payload: '{}')).to be(false)
      end
    end

    include_examples 'a mutating HTTP verb wrapper', :post, :post
    include_examples 'a mutating HTTP verb wrapper', :put, :put

    describe '.delete' do
      it 'executes a DELETE request' do
        allow(RestClient::Request).to receive(:execute).and_return(response)

        expect(described_class.delete(url: 'https://example.org/data',
                                      headers: { accept: 'application/json' },
                                      user: 'alice',
                                      pass: 'secret')).to eq(response)
        expect(RestClient::Request).to have_received(:execute).with(
          method: :delete,
          url: 'https://example.org/data',
          user: 'alice',
          password: 'secret',
          headers: { accept: 'application/json' }
        )
      end

      it 'returns false for HTTP response exceptions' do
        allow(RestClient::Request).to receive(:execute)
          .and_raise(RestClient::ExceptionWithResponse.new(error_response))

        expect(described_class.delete(url: 'https://example.org/data')).to be(false)
      end

      it 'returns false for other RestClient exceptions' do
        allow(RestClient::Request).to receive(:execute)
          .and_raise(HTTPUtilsSpecRestClientException.new(error_response))

        expect(described_class.delete(url: 'https://example.org/data')).to be(false)
      end

      it 'returns false for unexpected exceptions' do
        allow(RestClient::Request).to receive(:execute).and_raise(RuntimeError, 'boom')

        expect(described_class.delete(url: 'https://example.org/data')).to be(false)
      end
    end

    describe '.patchttl' do
      it 'moves prefix declarations before body statements' do
        patched = described_class.patchttl("ex:s ex:p ex:o .\n@prefix ex: <https://example.org/> .")

        expect(patched).to eq("@prefix ex: <https://example.org/> .\nex:s ex:p ex:o .")
      end
    end
  end

  describe DCATEndpointExtractor do
    let(:url) { 'https://example.org/dcat' }
    let(:extractor) { described_class.new(url: url) }

    def dcat_graph(*endpoints)
      dcat = RDF::Vocab::DCAT
      graph = RDF::Graph.new
      endpoints.each_with_index do |endpoint, index|
        service = RDF::URI("https://example.org/service/#{index}")
        graph << [service, RDF.type, dcat.DataService]
        graph << [service, dcat.endpointURL, RDF::URI(endpoint)]
      end
      graph
    end

    it 'initializes with an empty graph' do
      expect(extractor.url).to eq(url)
      expect(extractor.graph).to be_a(RDF::Graph)
      expect(extractor.graph).to be_empty
    end

    it 'loads JSON-LD DCAT and extracts the endpoint URL' do
      response = double('Response', headers: { content_type: 'application/ld+json' })
      graph = dcat_graph('https://api.example.org/data')
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(RDF::Graph).to receive(:load).with(url, format: :jsonld).and_return(graph)

      expect(extractor.extract_endpoint_url).to eq('https://api.example.org/data')
    end

    it 'detects Turtle content' do
      response = double('Response', headers: { content_type: 'text/turtle' })
      graph = dcat_graph('https://api.example.org/data')
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(RDF::Graph).to receive(:load).with(url, format: :turtle).and_return(graph)

      extractor.send(:load_rdf_data)

      expect(extractor.graph).to eq(graph)
    end

    it 'detects RDF/XML content' do
      response = double('Response', headers: { content_type: 'application/rdf+xml' })
      graph = dcat_graph('https://api.example.org/data')
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(RDF::Graph).to receive(:load).with(url, format: :rdfxml).and_return(graph)

      extractor.send(:load_rdf_data)

      expect(extractor.graph).to eq(graph)
    end

    it 'defaults unknown content to JSON-LD' do
      response = double('Response', headers: { content_type: 'application/octet-stream' })
      graph = dcat_graph('https://api.example.org/data')
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(RDF::Graph).to receive(:load).with(url, format: :jsonld).and_return(graph)

      extractor.send(:load_rdf_data)

      expect(extractor.graph).to eq(graph)
    end

    it 'raises a fetch error when the HTTP request fails' do
      allow(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)

      expect { extractor.send(:load_rdf_data) }.to raise_error(RuntimeError, /Failed to fetch RDF data/)
    end

    it 'raises a parse error when RDF loading fails' do
      response = double('Response', headers: { content_type: 'text/turtle' })
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(RDF::Graph).to receive(:load).and_raise(RDF::ReaderError.new('bad RDF'))

      expect { extractor.send(:load_rdf_data) }.to raise_error(RuntimeError, /Failed to parse RDF data/)
    end

    it 'returns the first endpoint when several are present' do
      extractor.instance_variable_set(:@graph, dcat_graph('https://api.example.org/one', 'https://api.example.org/two'))

      expect(extractor.send(:query_endpoint_url)).to eq('https://api.example.org/one')
    end

    it 'raises when no endpoint is present' do
      extractor.instance_variable_set(:@graph, RDF::Graph.new)

      expect { extractor.send(:query_endpoint_url) }.to raise_error(RuntimeError, /No dcat:endpointURL found/)
    end
  end

  describe 'OpenAPI helper methods' do
    describe '#fetch_json' do
      it 'fetches and parses JSON' do
        stub_request(:get, 'https://example.org/openapi.json')
          .to_return(status: 200, body: { openapi: '3.0.0' }.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(send(:fetch_json, 'https://example.org/openapi.json')).to eq('openapi' => '3.0.0')
      end

      it 'raises when the response is not successful' do
        stub_request(:get, 'https://example.org/missing.json').to_return(status: 404, body: 'missing')

        expect { send(:fetch_json, 'https://example.org/missing.json') }.to raise_error(RuntimeError, /Failed to fetch/)
      end
    end

    it 'converts Swagger through the configured converter service' do
      source_url = 'https://example.org/swagger.json'
      converter_url = "#{CONVERTER_BASE}/convert?url=#{URI.encode_www_form_component(source_url)}"
      stub_request(:get, converter_url)
        .to_return(status: 200, body: { openapi: '3.0.0' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(send(:convert_swagger_to_openapi, source_url)).to eq('openapi' => '3.0.0')
    end

    it 'turns templated OpenAPI paths into named-capture regexes' do
      regex = send(:template_to_regex, '/assess/test/{test_id}/result/{result_id}')

      match = regex.match('/assess/test/T1/result/R1')
      expect(match.named_captures).to eq('test_id' => 'T1', 'result_id' => 'R1')
      expect(regex).not_to match('/assess/test/T1/result/R1/extra')
    end

    it 'matches concrete paths to OpenAPI templates' do
      paths = {
        '/other/{id}' => :other,
        '/assess/test/{test_id}' => :assessment
      }

      expect(send(:match_path_to_template, '/assess/test/T1', paths)).to eq(
        template: '/assess/test/{test_id}',
        path_item: :assessment,
        param_values: { 'test_id' => 'T1' }
      )
    end

    it 'returns nil when no OpenAPI path template matches' do
      expect(send(:match_path_to_template, '/missing', { '/other/{id}' => :other })).to be_nil
    end

    it 'extracts operation parameters and JSON request body metadata' do
      schema = double('Schema', type: 'string', ref: '#/components/schemas/Input')
      parameter = double('Parameter', name: 'id', in: 'path', required: true, schema: schema, description: 'Identifier')
      media_type = double('Media type', schema: schema)
      request_body = double(
        'Request body',
        content: { 'application/json' => media_type },
        required: true,
        description: 'Input payload'
      )
      operation = double('Operation', parameters: [parameter], request_body: request_body)

      expect(send(:get_input_parameters, operation)).to eq([
                                                             {
                                                               name: 'id',
                                                               in: 'path',
                                                               required: true,
                                                               type: 'string',
                                                               description: 'Identifier',
                                                               schema_ref: '#/components/schemas/Input'
                                                             },
                                                             {
                                                               name: 'requestBody',
                                                               in: 'body',
                                                               required: true,
                                                               type: 'string',
                                                               description: 'Input payload',
                                                               schema_ref: '#/components/schemas/Input'
                                                             }
                                                           ])
    end

    it 'handles operations without parameters or JSON request bodies' do
      request_body = double('Request body', content: {}, required: false, description: nil)
      operation = double('Operation', parameters: nil, request_body: request_body)

      expect(send(:get_input_parameters, operation)).to eq([])
    end
  end
end
