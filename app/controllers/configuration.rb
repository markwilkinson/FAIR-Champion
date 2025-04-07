require 'parseconfig'

# testt = true
testt = false

if testt
  TEST_HOST = 'https://tests.ostrails.eu/tests'.freeze
  CHAMP_HOST = 'https://tools.ostrails.eu/champion'.freeze
  GRAPHDB_PROTOCOL = 'https'.freeze
  GRAPHDB_USER = 'champion'.freeze
  GRAPHDB_HOST = 'tools.ostrails.eu'.freeze
  GRAPHDB_PORT = '443'.freeze
  GRAPHDB_PASS = File.read('/tmp/championpass.txt').strip.freeze
  GRAPHDB_REPONAME = 'champion'.freeze
else
  TEST_HOST = ENV.fetch('TEST_HOST', 'https://tests.ostrails.eu/tests').gsub(%r{/+$}, '') unless defined? TEST_HOST
  unless defined? CHAMP_HOST
    CHAMP_HOST = ENV.fetch('CHAMP_HOST', 'https://tools.ostrails.eu/champion').gsub(%r{/+$},
                                                                                    '')
  end
  GRAPHDB_PROTOCOL = ENV.fetch('GRAPHDB_PROTOCOL', 'https') unless defined? GRAPHDB_PROTOCOL
  GRAPHDB_USER = ENV.fetch('GRAPHDB_USER') unless defined? GRAPHDB_USER
  GRAPHDB_PASS = ENV.fetch('GRAPHDB_PASS', 'champion') unless defined? GRAPHDB_PASS
  GRAPHDB_HOST = ENV.fetch('GRAPHDB_HOST') unless defined? GRAPHDB_HOST # relative on docker network
  GRAPHDB_PORT = ENV.fetch('GRAPHDB_PORT', 443) unless defined? GRAPHDB_PORT # relative on docker network
  GRAPHDB_REPONAME = ENV.fetch('GRAPHDB_REPONAME', 'champion') unless defined? GRAPHDB_REPONAME
end

CHAMPION_REPO = "#{GRAPHDB_PROTOCOL}://#{GRAPHDB_HOST}:#{GRAPHDB_PORT}/repositories/#{GRAPHDB_REPONAME}"
