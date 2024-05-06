require 'swagger/blocks'
# require 'sinatra/json'
require 'sinatra'
require 'sinatra/base'
require 'require_all'
# DO NOT change the order of loading below.  The files contain executable code that builds the overall configuration before this module starts
require_relative 'configuration'
require_relative 'models'
require_relative 'routes'
require_rel '../../lib'

class Swag < Sinatra::Application
  include Swagger::Blocks

  set :bind, '0.0.0.0'
  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
    enable :cross_origin
  end

  # routes...
  options '*' do
    response.headers['Allow'] = 'GET, PUT, POST, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token'
    response.headers['Access-Control-Allow-Origin'] = '*'
    200
  end

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, 'FAIR Champion Testing Service'
      key :description, 'Tests the metadata of your stuff'
      key :termsOfService, 'https://fairdata.services/champion/terms/'
      contact do
        key :name, 'Mark D Wilkinson'
      end
      license do
        key :name, 'MIT'
      end
    end

    tag do
      key :name, 'Get interface document'
      key :description, 'The main interface for the FAIR Champion'
      externalDocs do
        key :description, 'Information about how to use this service'
        key :url, 'https://fairdata.services/champion/about'
      end
    end
    key :schemes, ['https']
    key :host, 'fairdata.services'
    key :basePath, '/champion'
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [ErrorModel, NewSet, TheChampion, self].freeze

  set_routes(classes: SWAGGERED_CLASSES)

  run! # if app_file == $PROGRAM_NAME
end
