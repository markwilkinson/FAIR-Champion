require "rest_client"
require 'json'
require 'sparql'
require 'linkeddata'

module Champion
  class Core

    attr_accessor :sets, :host, :sethost
    def initialize
      # host = "http://fairdata.services:8282/tests"
      @host = "http://tests:4567/tests"
      @sethost = "http://tests:4567/sets/"
      @sets = get_sets()
    end

    def run_evaluation(subject:, setid:)
      warn "evaluating #{subject} on #{setid}"
      results = []
      sets[setid].each do |testy|
        results << run_test(guid: subject, testy: testy)
      end
#warn "RESULTS #{results}"
      output = Champion::Output.new(setid: setid, subject: subject)
      output.build_output(results: results)
    end

    def run_test(testy:, guid:)
      warn "web call to #{testy}"
      result = RestClient::Request.execute(
        url: testy,
        method: :post,
        payload: {"subject" => guid}.to_json,
        content_type: :json
      )
      JSON.parse(result.body)
    end

    def get_sets(setid: nil)
      warn "set requested #{setid}"
      sets = {"OSTrails1" => [
        "#{host}/fc_data_authorization",
        "#{host}/fc_data_identifier_in_metadata",
        "#{host}/fc_data_kr_language_strong",
        "#{host}/fc_data_kr_language_weak",
        "#{host}/fc_data_protocol",
        "#{host}/fc_metadata_persistence",
        "#{host}/fc_metadata_protocol",
        "#{host}/fc_unique_identifier",
      ]}
      if setid
        return sets[setid]
      else
        return sets
      end
    end
  end
end