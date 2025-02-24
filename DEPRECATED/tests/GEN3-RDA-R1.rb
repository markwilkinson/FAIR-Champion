require 'linkheaders/processor'

class AllTests
  # ====================================================================
  # Test 1
  define_method('GEN3-RDA-R1-1') do
    metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-R1-1'
    metadata.version = '1.0'

    encodedguid = encode_guid(guid: metadata.id)
    result = send('GEN3-RDA-R1-1_TEST', encodedguid)
    metadata.score = if result
                       1
                     else
                       -1
                     end
  end
  define_method('GEN3-RDA-R1-1_TEST') do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    warn "LINKSURL:  #{linksurl}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    p.extract_and_parse(response: r)
    factory = p.factory # LinkHeaders::LinkFactory

    item = false
    factory.all_links.each do |l|
      warn "relation #{l.relation}"
      if l.relation == 'item'
        item = true
        metadata.comments << 'INFO: The page contains an item signpost'
      end
    end
    about = false
    types = 0
    factory.all_links.each do |l|
      warn "relation #{l.relation}"
      next unless l.relation == 'type'

      type = l.href
      types += 1 # how many types?  Should be at least one for all signposting pages, should be at least two for an aboutpage
      if type =~ %r{https?://schema.org/AboutPage}
        about = true
        metadata.comments << 'INFO: The page is typed as an AboutPage'
      end
    end
    if about
      if item && types >= 2
        metadata.comments << 'PASS: The page is properly typed as an AboutPage with another semantic type'
        true
      elsif item && types < 2
        metadata.comments << 'FAIL: An AboutPage must also have a more specific semantic type'
        false
      else
        metadata.comments << 'FAIL: An AboutPage must contain at least one item'
        false
      end
    elsif item
      metadata.comments << 'FAIL: A page with an item should be typed as an AboutPage'
      false
    elsif types < 1
      metadata.comments << 'FAIL: All signposting pages must have at least one type'
      false
    else
      metadata.comments << 'PASS: The page is properly not typed as an AboutPage, because it contains no items'
      true
    end
  end
  # =================================================================================

  # ====================================================================
  # Test for 55-rda-r1-01m-t5-type-unresolve/   TODO
  #  this is going to use the test_helper rich_retrieve, because it needs to detect if a redirect has led to a failure
  # so the all_uris value of a new metadata object will tell us that
  # define_method('GEN3-RDA-R1-1t5') do
  #   metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-R1-1t5'
  #   metadata.version = '1.0'

  #   encodedguid = encode_guid(guid: metadata.id)
  #   result = send('GEN3-RDA-R1-1t5_TEST', encodedguid)
  #   metadata.score = if result
  #                      1
  #                    else
  #                      -1
  #                    end
  # end
  # define_method('GEN3-RDA-R1-1t5_TEST') do |encodedguid|
  #   linksurl = "#{LINK_SERVER}#{encodedguid}"
  #   warn "LINKSURL:  #{linksurl}"
  #   p = LinkHeaders::Processor.new(default_anchor: linksurl)
  #   r = RestClient.get(linksurl)
  #   p.extract_and_parse(response: r)
  #   factory = p.factory # LinkHeaders::LinkFactory
  # end
  # =================================================================================
  # ====================================================================
  # Test for 56-rda-r1-01m-t6-unfair   TODO
  #  It isn't clear what Stian considers to be suffient for an ontology term to be considered "FAIR"

  # =================================================================================
  # ====================================================================
  # Test for 56-rda-r1-01m-t6-unfair   TODO
  #  It isn't clear what Stian considers to be suffient for an ontology term to be considered "FAIR"


  # =================================================================================
  # ====================================================================
  # Test for   65-rda-r1-01m-t1-item-type
  # Every item should have a type
  define_method('GEN3-RDA-R1-t1') do
    metadata.test_guid = 'https://w3id.org/FAIR_Tests/Gen3/GEN3-RDA-R1-t1'
    metadata.version = '1.0'

    encodedguid = encode_guid(guid: metadata.id)
    result = send('GEN3-RDA-R1-t1_TEST', encodedguid)
    metadata.score = if result
                       1
                     else
                       -1
                     end
  end
  define_method('GEN3-RDA-R1-t1_TEST') do |encodedguid|
    linksurl = "#{LINK_SERVER}#{encodedguid}"
    warn "LINKSURL:  #{linksurl}"
    p = LinkHeaders::Processor.new(default_anchor: linksurl)
    r = RestClient.get(linksurl)
    unless r && r.body
      metadata.comments << 'FAIL: unable to parse the links.  This may not be your fault!'
      return false
    end

    p.extract_and_parse(response: r)
    factory = p.factory # LinkHeaders::LinkFactory
    factory.all_links.each do |l|
      warn "relation #{l.relation}"
      next unless l.relation == 'item'

      metadata.comments << "INFO: The page contains an item signpost #{l.href}"
      unless l.respond_to? 'type'
        metadata.comments << 'FAIL: The item does not have a type atttribute, which forbidden'
        return false
      end
      metadata.comments << "INFO: The declared type of the item is #{l.type}"
      unless l.type =~ /\S+\/\S+;?\s*(\S+)?/ 
        metadata.comments << 'FAIL: The item type attribute does not follow IANA standards of XXXX/YYYY'
        return false
      end
      unless iana_lookup(type: l.type)
        warn "LOOKUP FAILED"
        if (l.type =~ /application\/vnd/) or (l.type =~ /application\/priv/)
          metadata.comments << 'WARN: The item type attribute is not registered with IANA, however, it is decalred as being a private type.  This is acceptable.'
        else
          metadata.comments << 'FAIL: The item type attribute is not registered with IANA'
          return false
        end
      end
      metadata.comments << 'INFO: The item has a type attribute'
    end
    metadata.comments << 'PASS: All items had a type attribute that was found in IANA or was declared as private.'
    true
  end



end
