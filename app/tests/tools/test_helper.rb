require 'csv'

class AllTests
  attr_accessor :metadata

  METADATA_SERVER = 'http://seek.cbgp.upm.es:9000/fsp-harvester-server/ld?guid='
  LINK_SERVER = 'http://seek.cbgp.upm.es:9000/fsp-harvester-server/links?guid='

  def initialize(guid:)
    @metadata = TestingTools::MetadataObject.new(id: guid)
  end

  def retrieve(url:)
    warn "url #{url}"
    begin
      r = RestClient.get(url)
    rescue e
      metadata.comments << "FAIL:  GUID didn't resolve"
      return false
    end
    # warn "rest #{r.inspect}"
    JSON.parse(r.body)
  end

  def encode_guid(guid:)
    if guid =~ /%\d/
      ERB::Util.url_encode(guid)
    else
      guid
    end
  end

  def rich_retrieve(url:, headers: ACCEPT_STAR_HEADER, method: :get, meta: @metadata)
    warn 'In rich fetch routine now.  '

    begin
      warn "executing call over the Web to #{url}"
      response = RestClient::Request.execute({
                                              method: method,
                                              url: url.to_s,
                                              # user: user,
                                              # password: pass,
                                              headers: headers
                                            })
      meta.all_uris |= [response.request.url]  # it's possible to call this method without affecting the metadata object being created by the harvester
      warn "starting URL #{url}"
      warn "final URL #{response.request.url}"
      warn "Response code #{response.code}"
      if response.code == 203 
        meta.add_warning(["002", url, headers])
        meta.comments << "WARN: Response is non-authoritative (HTTP response code: #{response.code}).  Headers may have been manipulated encountered when trying to resolve #{url}\n"
      end
      response
    rescue RestClient::ExceptionWithResponse => e
      warn "EXCEPTION WITH RESPONSE! #{e.response.code} with response #{e.response}\nfailed response headers: #{e.response.headers}"
      meta.add_warning(["003", url, headers])
      meta.comments << "WARN: HTTP error #{e} encountered when trying to resolve #{url}\n"
      if (e.response.code == 500 or e.response.code == 404)
        return false
      else
        e.response
      end
      # now we are returning the headers and body that were returned
    rescue RestClient::Exception => e
      warn "EXCEPTION WITH NO RESPONSE! #{e}"
      meta.add_warning(["003", url, headers])
      meta.comments << "WARN: HTTP error #{e} encountered when trying to resolve #{url}\n"
      false
      # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    rescue Exception => e
      warn "EXCEPTION UNKNOWN! #{e}"
      meta.add_warning(["003", url, headers])
      meta.comments << "WARN: HTTP error #{e} encountered when trying to resolve #{url}\n"
      false
      # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    end
  end

  def iana_lookup(type:)
    type.gsub!(/\s*;.*/, "")
    medias = %w{https://www.iana.org/assignments/media-types/application.csv
    https://www.iana.org/assignments/media-types/audio.csv
    https://www.iana.org/assignments/media-types/font.csv
    https://www.iana.org/assignments/media-types/image.csv
    https://www.iana.org/assignments/media-types/message.csv
    https://www.iana.org/assignments/media-types/model.csv
    https://www.iana.org/assignments/media-types/multipart.csv
    https://www.iana.org/assignments/media-types/text.csv
    https://www.iana.org/assignments/media-types/video.csv}
    medias.each do |m|
      csv = RestClient.get(m).body
      arr_of_rows = CSV.parse(csv)
      arr_of_rows.each do |row|
        # warn "||#{row[1]}||"
        return true if row[1] == type
      end
    end
    return false
  end


  # :id, :hash, :graph, :comments, :links, :warnings, :guidtype,
  # :full_response, :all_uris, :tested_guid, :score, :version, :date,
  # :url_header_hash
  def build_result_hash
    res = {}
    res['guid'] = metadata.id
    res['score'] = metadata.score
    res['comments'] = metadata.comments
    res['warnings'] = metadata.warnings
    res['test_guid'] = metadata.test_guid
    res['version'] = metadata.version
    res['date'] = metadata.date
    res
  end

  def cache; end
end
