require 'rdf'
require 'rdf/turtle'
require 'rdf/json'
require 'rest-client'
require 'rdf/vocab'

# The DCATEndpointExtractor class retrieves and parses RDF data from a given URL
# to extract the DCAT endpoint URL for a data service.
class DCATEndpointExtractor
  include RDF

  # @!attribute [r] url
  #   @return [String] The URL of the RDF resource to parse.
  # @!attribute [r] graph
  #   @return [RDF::Graph] The RDF graph containing the parsed data.
  attr_reader :url, :graph

  # Initializes a new DCATEndpointExtractor instance with the given URL.
  #
  # @param url [String] The URL of the RDF resource (e.g., DCAT dataset or service description).
  # @return [DCATEndpointExtractor] A new instance of the DCATEndpointExtractor class.
  # @example
  #   extractor = DCATEndpointExtractor.new(url: 'https://example.org/dcat/service')
  def initialize(url:)
    @url = url
    @graph = RDF::Graph.new
  end

  # Extracts the DCAT endpoint URL from the RDF data.
  #
  # @return [String] The endpoint URL for the DCAT DataService.
  # @raise [RuntimeError] If the RDF data cannot be fetched, parsed, or if no endpoint URL is found.
  # @example
  #   extractor = DCATEndpointExtractor.new(url: 'https://example.org/dcat/service')
  #   endpoint = extractor.extract_endpoint_url
  #   puts endpoint # e.g., "https://api.example.org/data"
  def extract_endpoint_url
    load_rdf_data
    query_endpoint_url
  end

  private

  # Loads RDF data from the specified URL into an RDF graph.
  #
  # @return [void]
  # @raise [RuntimeError] If the HTTP request fails or the RDF data cannot be parsed.
  # @example
  #   extractor = DCATEndpointExtractor.new(url: 'https://example.org/dcat/service')
  #   extractor.send(:load_rdf_data)
  #   puts extractor.graph.dump(:turtle)
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

    # Queries the RDF graph to extract the DCAT endpoint URL.
  #
  # @return [String] The first unique endpoint URL found.
  # @raise [RuntimeError] If no dcat:endpointURL is found for a dcat:DataService.
  # @example
  #   extractor = DCATEndpointExtractor.new(url: 'https://example.org/dcat/service')
  #   extractor.send(:load_rdf_data)
  #   endpoint = extractor.send(:query_endpoint_url)
  #   puts endpoint # e.g., "https://api.example.org/data"
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

