require 'linkheaders/processor'

class AllTests



  #  three  tests:    
  # 1:  Do any of the describedby links point to a document that contains dcat, dc, or schema;  
  # 2:  does the promised encoding of that link match the actual content. 
  # 3: Richness requirements for discoverability are name, description, creator, date  ( as per https://eosc-edmi.github.io/properties).   
  # Three tests, all of which are pass/fail.
  # ====================================================================
  # Test 3
  define_method("GEN3-RDA-F2-3") do
    metadata.test_guid = "https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F2-3"
    metadata.version = "1.0"

    encodedguid = encode_guid(guid: metadata.id)
    signposting = retrieve(url: "#{METADATA_SERVER}#{encodedguid}")
    unless signposting
      metadata.score = -1
      return
    end

    result = send("GEN3-RDA-F2-3_TEST", signposting)
    if result
      metadata.score = 1
    else
      metadata.score = -1
    end
  end
  define_method("GEN3-RDA-F2-3_TEST") do |signposting|
    metadata.comments << "INFO: testing signposting metadata for sufficiently 'rich' discovery metadata (defined by EOSC-EDMI as name, description, creator, date)"
    graph = RDF::Graph.new
    data = StringIO.new(signposting.to_json)
    RDF::Reader.for(:jsonld).new(data) do |reader|
      reader.each_statement {|s| graph << s }
    end
    warn "Graph:  #{graph.size}"
    query = SPARQL.parse("SELECT distinct ?p WHERE { ?s ?p ?o } ")
    name = false; desc = false; creator = false; date = false
    # check for "name" or equivalent
    graph.query(query) do |result|
      if (result[:p] =~ %r{https?://schema\.org/name}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/title}) || 
      (result[:p] =~ %r{https?://purl.org/dc/terms/title}) 
        metadata.comments << "INFO: Found a name/title #{result[:p]}"
        name = true
        break
      end
    end
    metadata.comments << "INFO: Unable to find a name/title" unless name
    graph.query(query) do |result|
      warn "Checking result #{result.inspect}"
      if (result[:p] =~ %r{https?://schema\.org/datePublished}) || 
      (result[:p] =~ %r{https?://schema\.org/dateCreated}) || 
      (result[:p] =~ %r{https?://schema\.org/dateModified}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/date}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/issued}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/modified}) || 
      (result[:p] =~ %r{https?://purl.org/dc/terms/date}) 
        metadata.comments << "INFO: Found a date #{result[:p]} "
        date = true
        break
      end
    end
    metadata.comments << "INFO: Unable to find a date" unless date
    graph.query(query) do |result|
      if (result[:p] =~ %r{https?://schema\.org/author}) || 
      (result[:p] =~ %r{https?://schema\.org/creator}) || 
      (result[:p] =~ %r{https?://schema\.org/publisher}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/creator}) || 
      (result[:p] =~ %r{https?://purl.org/dc/terms/creator}) ||
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/publisher}) || 
      (result[:p] =~ %r{https?://purl.org/dc/terms/publisher}) 
        metadata.comments << "INFO: Found a publisher/author #{result[:p]} "
        creator = true
        break
      end
    end
    metadata.comments << "INFO: Unable to find a publisher/author" unless creator
    graph.query(query) do |result|
      if (result[:p] =~ %r{https?://schema\.org/description}) || 
      (result[:p] =~ %r{https?://purl.org/dc/elements/1.1/description}) || 
      (result[:p] =~ %r{https?://purl.org/dc/terms/description}) 
        metadata.comments << "INFO: Found a description #{result[:p]} "
        desc = true
        break
      end
    end
    metadata.comments << "INFO: Unable to find a description" unless desc
    if name && desc && date && creator
      metadata.comments << "PASS: Sufficient metadata fields found"
      return true
    else
      metadata.comments << "FAIL: insufficient discovery metadata fields"
      return false
    end
  end

# ---------------------------------------


  # ====================================================================
  # Test 2
  define_method("GEN3-RDA-F2-2") do
    metadata.comments << "INFO: testing signposting metadata to ensure that describedby link content type matches what is claimed"
    metadata.test_guid = "https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F2-2"
    metadata.version = "1.0"

    encodedguid = encode_guid(guid: metadata.id)

    result = send("GEN3-RDA-F2-2_TEST", encodedguid)
    if result
      metadata.score = 1
    else
      metadata.score = -1
    end
  end
  define_method("GEN3-RDA-F2-2_TEST") do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    p.extract_and_parse(response: r)
    factory = p.factory  # LinkHeaders::LinkFactory
  
    factory.all_links.each do |l| 
      next unless l.relation == "describedby"
      next unless l.respond_to? 'type'
      l.type = l.type.gsub(/json\+ld/, "ld+json")  # bug in dataverse
      warn "requesting #{l.href} with accept #{l.type} "
      this = RestClient::Request.execute(
        :method => :get,
        :url => l.href,
        :headers => {accept: l.type}
      )
      content = this.headers[:content_type]
      content = content.gsub(%r{\s*\;.*}, "")
      if content == l.type
        metadata.comments << "INFO: match of #{content} with #{l.type}"
        next
      else
        metadata.comments << "INFO: No match of #{content} with #{l.type}"
        metadata.comments << "FAIL: Declared content-type did not match returned content type"
        return false
      end
    end
    metadata.comments << "PASS: All declared content-types matched the returned content-types"
    true
  end


  # ====================================================================
  # Test 1
  define_method("GEN3-RDA-F2-1") do
    metadata.test_guid = "https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F2-1"
    metadata.version = "1.0"

    encodedguid = encode_guid(guid: metadata.id)
    signposting = retrieve(url: "#{METADATA_SERVER}#{encodedguid}")
    unless signposting
      metadata.score = -1
      return
    end

    result = send("GEN3-RDA-F2-1_TEST", signposting)
    if result
      metadata.score = 1
    else
      metadata.score = -1
    end
  end
  define_method("GEN3-RDA-F2-1_TEST") do |signposting|
    metadata.comments << "INFO: testing signposting metadata for schema.org, dcat, and dublin-core links"
    graph = RDF::Graph.new
    data = StringIO.new(signposting.to_json)
    RDF::Reader.for(:jsonld).new(data) do |reader|
      reader.each_statement {|s| graph << s }
    end
    query = SPARQL.parse("SELECT ?p WHERE { ?s ?p ?o } ")
    graph.query(query) do |result|
      if (result[:p] =~ %r{https?://schema\.org}) || (result[:p] =~ %r{https?://purl.org/dc/elements}) || (result[:p] =~ %r{https?://purl.org/dc/terms})  || (result[:p] =~ %r{https?://www.w3.org/ns/dcat})
        metadata.comments << "INFO: Found at least one link that uses a common discovery metadata standard"
        metadata.comments << "PASS: Discovery metadata found"
        return true
      end
    end
    metadata.comments << "INFO: was unable to find any discovery metadata (checked for dublin core, schema.org, and dcat)"
    metadata.comments << "FAIL: No metadata found that folllows a common discovery metadata format"
    return false
  end
  # =================================================================================

end
