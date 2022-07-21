class MetadataObject
  attr_accessor :hash, :graph, :comments, :warnings, :guidtype, :full_response, :finalURI  # a hash of metadata # a RDF.rb graph of metadata  # an array of comments  # the type of GUID that was detected # will be an array of Net::HTTP::Response

  def initialize(_params = {}) # get a name from the "new" call, or set a default
    @hash = Hash.new
    @graph = RDF::Graph.new
    @comments =  Array.new
    @warnings =  Array.new
    @full_response = Array.new
    @finalURI = Array.new
  end

  def merge_hash(hash)
    # $stderr.puts "\n\n\nIncoming Hash #{hash.inspect}"
    self.hash = self.hash.merge(hash)
  end

  def merge_rdf(triples)  # incoming list of triples
    self.graph << triples
    self.graph
  end

  def rdf
    self.graph
  end
end
