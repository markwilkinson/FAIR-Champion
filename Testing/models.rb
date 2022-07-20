class ErrorModel  # Notice, this is just a plain ruby object.
  include Swagger::Blocks

  swagger_schema :ErrorModel do
    key :required, %i[code message]
    property :code do
      key :type, :integer
      key :format, :int32
    end
    property :message do
      key :type, :string
    end
  end
end

class InputScheme # Notice, this is just a plain ruby object.
  include Swagger::Blocks

  swagger_schema :InputScheme do
    key :required, %i[guid]
    property :guid do
      key :type, :string
    end
  end
end

class EvalResponse # Notice, this is just a plain ruby object.
  include Swagger::Blocks

  swagger_schema :EvalResponse do
    key :required, %i[placeholder]  # figure out output structure
    property :placeholder do
      key :type, :integer
      key :format, :int32
    end
  end
end

class AllTests
  include Swagger::Blocks
  $th.each do |guid, val|
    swagger_path "/#{val['title']}" do
      operation :get do
        key :summary, "retrieve the interface for #{guid}"
        key :description, 'returns the swagger docs for all tests known on this host'
        key :operationId, "#{val['title']}_retrieve"
        key :tags, [(val['title']).to_s]
        key :produces, [
          'application/json'
        ]
        response 200 do
          key :description, 'service description in swagger'
        end
      end

      operation :post do
        key :description, (val['description']).to_s
        key :operationId, "#{val['title']}_execute"
        key :tags, [(val['title']).to_s]
        key :produces, [
          'application/json'
        ]
        key 'x-author', [(val['responsible_developer']).to_s]
        parameter do
          key :name, :guid
          key :in, :body
          key :description, 'The GUID to evaluate'
          key :required, true
          schema do
            key :'$ref', :InputScheme
          end
        end
        response 200 do
          key :description, 'Evaluation Response'
          schema do
            key :'$ref', :EvalResponse
          end
        end
        response :default do
          key :description, 'unexpected error'
          schema do
            key :'$ref', :ErrorModel
          end
        end
      end
    end
  end
end
