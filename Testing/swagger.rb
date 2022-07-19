require 'swagger/blocks'
require 'sinatra/json'
require 'sinatra'
require 'sinatra/base'
require_relative './configuration.rb'
require_relative './models.rb'
#require_relative './routes.rb'
#require_relative './swagger.rb'

class Swag < Sinatra::Application
  include Swagger::Blocks

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, 'Swagger Petstore'
      key :description, 'A sample API that uses a petstore as an example to ' \
                        'demonstrate features in the swagger-2.0 specification'
      key :termsOfService, 'http://helloreverb.com/terms/'
      contact do
        key :name, 'Wordnik API Team'
      end
      license do
        key :name, 'MIT'
      end
    end
    tag do
      key :name, 'pet'
      key :description, 'Pets operations'
      externalDocs do
        key :description, 'Find more info here'
        key :url, 'https://swagger.io'
      end
    end
    key :host, 'petstore.swagger.wordnik.com'
    key :basePath, '/api'
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [ ErrorModel,
    self  ].freeze

  get '/' do
    json Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end


  run! #if app_file == $PROGRAM_NAME

end
