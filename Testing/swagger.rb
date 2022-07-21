require 'swagger/blocks'
require 'sinatra/json'
require 'sinatra'
require 'sinatra/base'
# DO NOT change the order of loading below.  The files contain executable code that builds the overall configuration before this module starts
require_relative './configuration.rb'
require_relative './models.rb'
require_relative './routes.rb'

class Swag < Sinatra::Application
  include Swagger::Blocks

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, 'FAIR Champion Testing Service'
      key :description, 'Tests the metadata of your stuff'
      key :termsOfService, 'https://fairdata.services/Champion/terms/'
      contact do
        key :name, 'Mark D Wilkinson'
      end
      license do
        key :name, 'MIT'
      end
    end

# guid = "https://w3id.org/FAIR-Tests/gen3_unique_identifier"
# title = "gen3_unique_identifier"
# description = "mark gest"
# applies_to_principle = "F1"
# tests_metric = 'X0'
# version = "999"
# organization = "Marks place"
# org_url = "http://fairdata.services"
# responsible_developer = "Mark Wilkinson"
# email = "markw@illuminae.com"
# developer_orcid = "0000-0000-0000-000X"
    tag do
      key :name, $th.keys.first
      key :description, 'All Tests'
      externalDocs do
        key :description, 'Find more info here'
        key :url, 'https://fairdata.services/Champion/about'
      end
    end
    key :schemes, ["https"]
    key :host, 'fairdata.services:8181'
    key :basePath, '/tests'
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [ ErrorModel, InputScheme, EvalResponse, AllTests, self].freeze

  set_routes(classes: SWAGGERED_CLASSES)

  run! # if app_file == $PROGRAM_NAME

end
