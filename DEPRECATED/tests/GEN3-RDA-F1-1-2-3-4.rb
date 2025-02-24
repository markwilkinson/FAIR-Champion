require 'linkheaders/processor'

class AllTests
  define_method('GEN3-RDA-F1-1-2-3-4') do
    metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F1-1-2-3-4'
    metadata.version = '1.0'
    encodedguid = encode_guid(guid: metadata.id)

    result = send('GEN3-RDA-F1-1-2-3-4_TEST', encodedguid)
    metadata.score = if result
                       1
                     else
                       0
                     end
  end
  define_method('GEN3-RDA-F1-1-2-3-4_TEST') do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    warn "Links URL is #{linksurl}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    p.extract_and_parse(response: r)
    factory = p.factory # LinkHeaders::LinkFactory

    factory.all_links.each do |l|
      next unless l.relation == 'cite-as'
      warn l.inspect
      guid = l.href
      succ = false
      FspHarvester::PERSISTENTID_TYPES.each do |type, regex|
        metadata.comments << "INFO: testing #{guid} against regexp for #{type}"
        if regex.match(guid) 
          succ = true
          break
        end
      end
      unless succ
        metadata.comments << "INFO: cite-as should be a persistent ID.  The identifier #{guid} did not match a known type"
        metadata.comments << "INDETERMINATE:  Non-persistent metadata GUID found. This is an 'edge-case',and is not necessary for FAIR signposting scenarios.  Nevertheless, if you are certain that this identifier is persistent, please register the schema with FAIRsharing.org"
        return false
      end
      metadata.comments << 'PASS:  The cite-as URL matched a known persistent identifier schema.'
    end
    true
  end

  # ----------------------------------------------------------------------
  define_method('GEN3-RDA-F1-1') do
    metadata.comments << 'INFO: testing metadata GUID to see if it is persistent'
    metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F1-1'
    metadata.version = '1.0'

    encodedguid = encode_guid(guid: metadata.id)

    result = send('GEN3-RDA-F1-1_TEST', encodedguid)
    metadata.score = if result
                       1
                     else
                       0
                     end
  end
  define_method('GEN3-RDA-F1-1_TEST') do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    p.extract_and_parse(response: r)
    factory = p.factory # LinkHeaders::LinkFactory

    factory.all_links.each do |l|
      next unless l.relation == 'describedby'

      guid = l.href
      succ = false
      FspHarvester::PERSISTENTID_TYPES.each do |type, regex|
        metadata.comments << "INFO: testing #{guid} against regexp for #{type}"
        if regex.match(guid) 
          succ = true
          break
        end
      end
      unless succ
        metadata.comments << "INFO: #{guid} did not match a known type"
        metadata.comments << "INDETERMINATE:  Non-persistent metadata GUID found. This is an 'edge-case',and is not necessary for FAIR signposting scenarios.  Nevertheless, if you are certain that this identifier is persistent, please register the schema with FAIRsharing.org"
        return false
      end
      metadata.comments << 'PASS:  All metadata identifiers matched a known persistent identifier schema.'
    end
    true
  end



#----------------------------------------
  # ----------------------------------------------------------------------
  define_method('GEN3-RDA-F1d-1') do
    metadata.comments << 'INFO: testing data GUID to see if it is persistent'
    metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-F1d-1'
    metadata.version = '1.0'

    encodedguid = encode_guid(guid: metadata.id)

    result = send('GEN3-RDA-F1d-1_TEST', encodedguid)
    metadata.score = if result
                       1
                     else
                       0
                     end
  end
  define_method('GEN3-RDA-F1d-1_TEST') do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    warn "LINKSURL:  #{linksurl}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    p.extract_and_parse(response: r)
    factory = p.factory # LinkHeaders::LinkFactory

    factory.all_links.each do |l|
      warn "relation #{l.relation}"
      next unless l.relation == 'item'

      guid = l.href
      succ = false
      FspHarvester::PERSISTENTID_TYPES.each do |type, regex|
        metadata.comments << "INFO: testing #{guid} against regexp for #{type} #{regex}"
        if m = regex.match(guid) 
          succ = true
          warn "REGEX MATCH! #{m.inspect}"
          break
        end
      end
      unless succ
        metadata.comments << "INFO: #{guid} did not match a known type"
        metadata.comments << "INDETERMINATE:  Non-persistent data GUID found. This is an 'edge-case',and is not necessary for FAIR signposting scenarios.  Nevertheless, if you are certain that this identifier is persistent, please register the schema with FAIRsharing.org"
        return false
      end
      metadata.comments << 'PASS:  All data identifiers matched a known persistent identifier schema.'
    end
    true
  end

end
