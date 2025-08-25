
# configuration.rb
require 'dotenv/load' # Loads .env file in development

module Configuration

  def self.env
    ENV['RACK_ENV'] || 'development'
  end

  def self.test_host  #   TEST_HOST = 'https://tests.ostrails.eu/tests'.freeze
    ENV['TEST_HOST'] || 'https://tests.ostrails.eu/tests'
  end
#    CHAMP_HOST = .freeze
  def self.champ_host
    ENV['CHAMP_HOST'] || 'https://tools.ostrails.eu/champion'
  end
#    GRAPHDB_PROTOCOL = 'https'.freeze
  def self.graphdb_protocol
    ENV['GRAPHDB_PROTOCOL'] || 'https'
  end
#  GRAPHDB_USER = 'champion'.freeze
  def self.graphdb_user
    ENV['GRAPHDB_USER'] || 'champion'
  end
#   GRAPHDB_HOST = ''.freeze
  def self.graphdb_host
    ENV['GRAPHDB_HOST'] || 'tools.ostrails.eu'
  end
#   GRAPHDB_PORT = '443'.freeze
  def self.graphdb_port
    ENV['GRAPHDB_PORT'] || '443'
  end
  # GRAPHDB_PASS = 
  def self.graphdb_pass
    ENV['GRAPHDB_PASS']
  end
#   GRAPHDB_REPONAME = ''.freeze
  def self.graphdb_reponame
    ENV['GRAPHDB_REPONAME'] || 'champion'
  end
#  FDPINDEX_SPARQL = 
  def self.fdpindex_sparql
    ENV['FDPINDEX_SPARQL'] || 'https://tools.ostrails.eu/repositories/fdpindex-fdp'
  end

  def self.fdp_index_proxy
    ENV['FDPINDEXPROXY'] || 'https://tools.ostrails.eu/fdp-index-proxy/proxy'
  end

  def self.champion_host
    ENV['CHAMPION_HOST'] || 'https://tools.ostrails.eu/champion'
  end

  # TEST_HOST = ENV.fetch('TEST_HOST', 
  def self.test_host
    ENV['TEST_HOST'] || 'https://tests.ostrails.eu/tests'
  end

  # deprecated
  def self.champion_repo
    "#{GRAPHDB_PROTOCOL}://#{GRAPHDB_HOST}:#{GRAPHDB_PORT}/repositories/#{GRAPHDB_REPONAME}".freeze
  end

end






