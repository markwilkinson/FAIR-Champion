class ErrorModel  
  include Swagger::Blocks

  swagger_schema :ErrorModel do
    key :required, [:code, :message]
    property :code do
      key :type, :integer
      key :format, :int32
    end
    property :message do
      key :type, :string
    end
  end
end


class NewSetInput
  include Swagger::Blocks

  swagger_schema :NewSetInput do
    key :required, [:title, :description, :email, :tests]
    property :title do
      key :type, :string
    end
    property :description do
      key :type, :string
    end
    property :email do
      key :type, :string
    end
    property :tests do
      key :type, :array
      items do
        key :type, :string
      end
    end
  end
end


# class Pet
#   include Swagger::Blocks

#   swagger_schema :Pet do
#     key :required, [:id, :name]
#     property :id do
#       key :type, :integer
#       key :format, :int64
#     end
#     property :name do
#       key :type, :string
#     end
#     property :tag do
#       key :type, :string
#     end
#   end

#   swagger_schema :PetInput do
#     allOf do
#       schema do
#         key :'$ref', :Pet
#       end
#       schema do
#         key :required, [:name]
#         property :id do
#           key :type, :integer
#           key :format, :int64
#         end
#       end
#     end
#   end

  # ...
# end
# class EvalResponse # Notice, this is just a plain ruby object.
#   include Swagger::Blocks

#   swagger_schema :EvalResponse do
#     key :required, %i[placeholder]  # figure out output structure
#     property :placeholder do
#       key :type, :integer
#       key :format, :int32
#     end
#   end
# end

class TheChampion
  include Swagger::Blocks
  swagger_path "/" do
    operation :get do
      key :summary, "Retrieve the interface for FAIR Champion"
      key :description, 'returns the swagger docs this host'
      key :operationId, "Champion_retrieve"
      key :tags, 'interface'
      key :produces, ['application/json']
      response 200 do
        key :description, 'service description in swagger'
      end
    end
  end

  swagger_path "/sets" do
    operation :get do
      key :summary, "Retrieve the known Test Sets in this instance of the FAIR Champion"
      key :description, 'Retrieve the known Test Sets in this instance of the FAIR Champion'
      key :operationId, "Champion_sets"
      key :tags, 'sets'
      key :produces, ['application/json']
      response 200 do
        key :description, 'list of sets in json'
      end
    end

    operation :post do
      key :description, "Create a new Test Set"
      key :operationId, "Champion_create_set"
      key :tags, "createset"
      key :produces, [
        'application/json'
      ]  
      parameter do
        key :name, :setdefinition
        key :in, :body
        key :description, 'The definition of the Test Set'
        key :required, true
        schema do
          key :'$ref', :NewSetInput
        end
      end
      response 201 do  # created
        key :description, 'Create Set Response'
      end
      response :default do
        key :description, 'unexpected error'
        schema do
          key :'$ref', :ErrorModel
        end
      end
    end
  end
  
  swagger_path "/sets/{setid}" do
    operation :get do
      key :summary, "Retrieve the test set numbered in the URL"
      key :description, 'Retrieve the test set numbered in the URL'
      key :operationId, "Champion_set"
      key :tags, 'set'
      key :produces, ['application/json']
      response 200 do
        key :description, 'a specific sets in json'
      end
      parameter do
        key :name, :guid
        key :in, :path
        key :description, 'The GUID to evaluate'
        key :required, true
        key :type, :integer
      end
    end
  end
end

    # operation :post do
    #   key :description, (val['description']).to_s
    #   key :operationId, "#{val['title']}_execute"
    #   key :tags, [(val['title']).to_s]
    #   key :produces, [
    #     'application/json'
    #   ]
    #   key 'x-author', [(val['responsible_developer']).to_s]
    #   parameter do
    #     key :name, :guid
    #     key :in, :body
    #     key :description, 'The GUID to evaluate'
    #     key :required, true
    #     schema do
    #       key :'$ref', :InputScheme
    #     end
    #   end
    #   response 200 do
    #     key :description, 'Evaluation Response'
    #     schema do
    #       key :'$ref', :EvalResponse
    #     end
    #   end
    #   response :default do
    #     key :description, 'unexpected error'
    #     schema do
    #       key :'$ref', :ErrorModel
    #     end
    #   end
    # end
