require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
require 'rest-client'
require 'erb'


require_relative 'tools/constants'
require_relative 'tools/test_helper'
require_relative 'tools/metadata_object'

require_relative 'GEN3-RDA-F1-1-2-3-4'
require_relative 'GEN3-RDA-F2'
require_relative 'GEN3-RDA-R1'

class MyApp < Sinatra::Application


  get '/tests/:test' do
    content_type :json
    guid = params[:guid]
    testname = params[:test]
    if guid
      t = AllTests.new(guid: guid)
      t.send(testname.to_sym)
    end
    json t.build_result_hash  # t contains the metadata object
  end




  run! if app_file == $PROGRAM_NAME
end
