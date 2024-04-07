require 'rest_client'
require 'json'
require 'sparql'
require 'linkeddata'

module Champion
  class Core
    attr_accessor :sets, :testhost, :champhost

    def initialize
      # @testhost = "http://tests:4567/tests/"
      @testhost = ENV["TESTHOST"]
      # @testhost = 'http://fairdata.services:8282/tests/'
      @champhost = ENV["CHAMPHOST"]
      # @champhost = 'http://fairdata.systems:8383/sets/'
      # @champhost = 'http://localhost:4567/sets/'
      @testhost.gsub!(/\/+$/, "")
      @sets = get_sets
    end

    def run_evaluation(subject:, setid:)
      warn "evaluating #{subject} on #{setid}"
      setid = setid.to_sym
      results = []
      sets[setid].each do |testurl|
        results << run_test(guid: subject, testurl: testurl)
      end
      # warn "RESULTS #{results}"
      output = Champion::Output.new(setid: "#{champhost}#{setid}", subject: subject)
      output.build_output(results: results)
    end

    def run_test(testurl:, guid:)
      warn "web call to #{testurl}"
      result = RestClient::Request.execute(
        url: testurl,
        method: :post,
        payload: { 'subject' => guid }.to_json,
        content_type: :json
      )
      JSON.parse(result.body)
    end

    def get_sets(setid: nil)
      setid = setid.to_sym if setid

      # Dir.entries("../cache/*.json")
      # g = RDF::Graph.new

      warn "set requested #{setid}"
      sets = { OSTrails1: [
        "#{testhost}/fc_data_authorization",
        "#{testhost}/fc_data_identifier_in_metadata",
        "#{testhost}/fc_data_kr_language_strong",
        "#{testhost}/fc_data_kr_language_weak",
        "#{testhost}/fc_data_protocol",
        "#{testhost}/fc_metadata_persistence",
        "#{testhost}/fc_metadata_protocol",
        "#{testhost}/fc_unique_identifier"
      ] }
      return sets[setid] if setid

      sets
    end
  end
end
