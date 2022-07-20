require 'parseconfig'

class TestConfiguration
  attr_accessor :debug, :title, :tests_metric, :description, :applies_to_principle, :version, :organization, :org_url,
                :responsible_developer, :email, :developer_ORCiD, :protocol, :host, :basePath, :path,
                :response_description, :schemas, :comments, :fairsharing_key_location, :score, :testedGUID

  def initialize(params = {})
    @debug = params.fetch(:debug, false)

    @title = params.fetch(:title, 'unnamed')
    @tests_metric = params.fetch(:tests_metric, 'X0')
    @description = params.fetch(:description, 'default_description')
    @applies_to_principle = params.fetch(:applies_to_principle, 'some principle')
    @version = params.fetch(:version, '999999999999999')
    @organization = params.fetch(:organization, 'Some Organization')
    @org_url = params.fetch(:org_url, 'http://example.org')
    @responsible_develper = params.fetch(:responsible_developer, 'Some Person')
    @email = params.fetch(:email, 'name@example.org')
    @developer_orcid = params.fetch(:developer_ORCiD, '0000-0000-0000-0000')
    @host = params.fetch(:host, 'example.org')
    @protocol = params.fetch(:protocol, 'https')
    @basepath = params.fetch(:basepath, 'fair_tests')
    @path = params.fetch(:path, 'unnamed')
    @response_description = params.fetch(:response_description, 'undescribed')
    @schemas = params.fetch(:schemas, [])
    @comments = params.fetch(:comments, [])
    @fairsharing_key_location = params.fetch(:fairsharing_key_location, 'localhost')
    @score = params.fetch(:score, 0)
    @testedGUID = params.fetch(:testedGUID, 'http://example.org')
  end

  $th = {}
  Dir['*.conf'].each do |file|
    config = ParseConfig.new(file)
    #warn config.inspect
    id = config['metadata']['guid']
    $th[id] = Hash.new
    #warn id
    %w[title description applies_to_principle tests_metric version organization org_url responsible_developer email
       developer_orcid].each do |param|
      $th[id][param] = config['metadata'][param]
    end
  end
  #warn $th.inspect
end
