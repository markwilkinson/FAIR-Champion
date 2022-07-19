
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