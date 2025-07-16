require 'rdf'
require 'rdf/turtle'
require 'rdf/json'
require 'rest-client'
require 'rdf/vocab'

class DCATEndpointExtractor
  include RDF

  def initialize(url:)
    @url = url
    @graph = RDF::Graph.new
  end

  def extract_endpoint_url
    load_rdf_data
    query_endpoint_url
  end

  private

  def load_rdf_data
    begin
      # Fetch RDF data with RestClient, following redirects
      response = RestClient::Request.execute(
        method: :get,
        url: @url,
        headers: { accept: 'application/ld+json, text/turtle, application/rdf+xml' },
        max_redirects: 10
      )

      # Detect content type to determine RDF format
      content_type = response.headers[:content_type]
      format = case content_type
               when /application\/ld\+json/ then :jsonld
               when /text\/turtle/ then :turtle
               when /application\/rdf\+xml/ then :rdfxml
               else :jsonld # Default to JSON-LD as it’s common for DCAT
               end

      # Load data into RDF graph
      @graph = RDF::Graph.load(@url, format: format)
    rescue RestClient::Exception => e
      raise "Failed to fetch RDF data from #{@url}: #{e.message}"
    rescue RDF::ReaderError => e
      raise "Failed to parse RDF data: #{e.message}"
    end
  end

  def query_endpoint_url
    dcat = RDF::Vocab::DCAT
    solutions = RDF::Query.execute(@graph) do
      pattern [:service, RDF.type, dcat.DataService]
      pattern [:service, dcat.endpointURL, :endpoint]
    end

    endpoints = solutions.map { |solution| solution[:endpoint].to_s }.uniq
    if endpoints.empty?
      raise "No dcat:endpointURL found for dcat:DataService in #{@url}"
    elsif endpoints.size > 1
      puts "Warning: Multiple endpointURLs found, returning the first one."
    end
    endpoints.first
  end
end

