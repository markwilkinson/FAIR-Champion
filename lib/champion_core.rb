require "rest_client"
require 'json'
require 'sparql'
require 'linkeddata'

module Champion
  class Core

    attr_accessor :sets
    def initialize
#      host = "https://fairdata.systems/tests"
      host = "http://localhost:8080/tests"
      @sets = {"FCSET1" => [
        "#{host}/fc_data_authorization",
        "#{host}/fc_data_identifier_in_metadata",
        "#{host}/fc_data_kr_language_strong",
        "#{host}/fc_data_kr_language_weak",
        "#{host}/fc_data_protocol",
        "#{host}/fc_metadata_persistence",
        "#{host}/fc_metadata_protocol",
        "#{host}/fc_unique_identifier",
      ]}

    end

    def run_evaluation(subject:, setid:)
      results = []
      sets[setid].each do |test|
        results << run_test(guid: subject, test: test)
      end
#warn "RESULTS #{results}"
      output = Champion::Output.new(setid: setid, subject: subject)
      output.build_output(results: results)
    end

    def run_test(test:, guid:)
      result = RestClient::Request.execute(
        url: test,
        method: :post,
        payload: {"subject" => guid}.to_json,
        content_type: :json
      )
      JSON.parse(result.body)
    end
  end
end