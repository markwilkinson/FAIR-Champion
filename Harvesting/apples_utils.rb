require 'json'
require 'linkeddata'
require 'json/ld'
require 'json/ld/preloaded'
require 'linkheader-processor'
require 'addressable'
require 'tempfile'
require 'xmlsimple'
require 'nokogiri'
require 'parseconfig'
require 'rest-client'
require 'cgi'
require 'digest'
require 'open3'
require 'metainspector'
require 'rdf/xsd'
require_relative './metadata_object'
require_relative './constants'
require_relative './web_utils'

# require 'pry'

class ApplesUtils
  #@@distillerknown = {} # global, hash of sha256 keys of message bodies - have they been seen before t/f
  @warnings = JSON.parse(File.read('warnings.json'))
  @meta = MetadataObject.new

  def self.resolve_guid(guid:)
    url = self.convertToURL(guid: guid)
    links, @meta = self.resolve_url(url: url)
    return [links, @meta]
  end


  def self.convertToURL(guid:)
    GUID_TYPES.each do |k, regex|
        if k == "inchi" and regex.match(guid)
          return "inchi", "https://pubchem.ncbi.nlm.nih.gov/rest/rdf/inchikey/#{guid}"
        elsif k == "handle1" and regex.match(guid)
          return "handle", "http://hdl.handle.net/#{guid}"
        elsif k == "handle2" and regex.match(guid)
          return "handle", "http://hdl.handle.net/#{guid}"
        elsif k == "uri" and regex.match(guid)
          return "uri", guid
        elsif k == "doi" and regex.match(guid)
          return "doi", "https://doi.org/#{guid}"
        end
    end
    return nil, nil
  end                   
                     
  
  def self.typeit(guid:)
    Utils::GUID_TYPES.each do |type,regex|
        if regex.match(guid)
          return type
        end
    end
    return false
  end

  def self.resolve_url(url:, nolinkheaders: false, header: ACCEPT_ALL_HEADER)
    @meta.guidtype = 'uri' if @meta.guidtype.nil?
    warn "\n\n FETCHING #{url} #{header}\n\n"
    response = fetch(guid, header)
    warn "\n\n head #{response.head.inspect}\n\n"

    unless response
      @meta.warnings << ['001', url, header]
      @meta.comments << "WARN: Unable to resolve #{url} using HTTP Accept header #{header}.\n"
      return [[], @meta]
    end

    @meta.comments << "INFO: following redirection using this header led to the following URL: #{@meta.finalURI.last}.  Using the output from this URL for the next few tests..."
    @meta.full_response << response.body

    links = self.process_link_headers(response: response) unless nolinkheaders
    return [links, @meta]
  end


  def self.process_link_headers(response: response)
    returnlinks = []

    parser = LinkHeader::Parser.new(default_anchor: @meta.finalURI.last)
    p.extract_and_parse(response: response)
    factory = parser.factory  # LinkHeader::LinkFactory

    citeas = 0
    describedby = 0
    factory.all_links.each do |l|
      case l.relation
      when 'cite-as'
        citeas += 1
      when 'describedby'
        describedby += 1
      end
    end
    unless citeas == 1 && describedby > 0
      @meta.warnings << ['004', guid, header]
      @meta.comments << "The resource does not follow the FAIR Signposting standard, which requires exactly one cite-as header, and at least one describedby header\n"
    end
    returnlinks
  end


end
