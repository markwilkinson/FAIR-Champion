require 'sinatra'
require 'sinatra/base'
require 'require_all'
require_relative 'configuration'
require_relative 'routes'
require_rel '../../lib'

module Champion


  class ChampionApp < Sinatra::Application
    set_routes

    run! # if app_file == $PROGRAM_NAME
  end
  
  class Core
    testt = true
    if testt
      TEST_HOST = 'https://tests.ostrails.eu/tests'.freeze
      CHAMP_HOST = 'https://tools.ostrails.eu/champion'.freeze
      GRAPHDB_USER = 'champion'.freeze
      GRAPHDB_HOST = '128.131.169.191'.freeze
      GRAPHDB_PORT = '443'.freeze
      GRAPHDB_PASS = File.read('/tmp/championpass.txt').strip.freeze
      GRAPHDB_REPONAME = 'champion'.freeze
    else
      TEST_HOST = ENV.fetch('TEST_HOST', 'https://tests.ostrails.eu/tests').gsub(%r{/+$}, '') unless defined? TEST_HOST
      unless defined? CHAMP_HOST
        CHAMP_HOST = ENV.fetch('CHAMP_HOST', 'https://tools.ostrails.eu/champion').gsub(%r{/+$},
                                                                                        '')
      end
      GRAPHDB_USER = ENV.fetch('GRAPHDB_USER') unless defined? GRAPHDB_USER
      GRAPHDB_PASS = ENV.fetch('GRAPHDB_PASS', 'champion') unless defined? GRAPHDB_PASS
      GRAPHDB_HOST = ENV.fetch('GRAPHDB_HOST') unless  defined? GRAPHDB_HOST # relative on docker network
      GRAPHDB_PORT = ENV.fetch('GRAPHDB_PORT') unless  defined? GRAPHDB_PORT # relative on docker network
      GRAPHDB_REPONAME = ENV.fetch('GRAPHDB_REPONAME', 'champion') unless defined? GRAPHDB_REPONAME
    end
    CHAMPION_REPO = "http://#{GRAPHDB_HOST}:#{GRAPHDB_PORT}/repositories/#{GRAPHDB_REPONAME}"
  end

end
