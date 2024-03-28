requrie "rest_client"

module Champion
  class Core

    attr_accessor :sets
    def initialize
      host = "https://fairdata.systems/tests"
      @sets = {FCSET1: [
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

    def self.run_evaluation(guid:, setid:)
      results = []
      sets[setid].each do |test|
        results << self.run_test(guid: guid, test: test)
      end

      output = Champion::Output.new(set: setid, guid: guid)
      final = output.build_output(results: results)
      return final
    end

    def self.run_test(test:, guid:)
      result = RestClient::Request.execute(
        url: test,
        method: :post,
        payload: {"subject" => guid}.to_json,
        content_type: :json
      )
      return result.body

    end

  end

end