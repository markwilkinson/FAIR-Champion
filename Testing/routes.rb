

get '/test2' do
  fork do
    $config = TestConfiguration.new
    $config.version = 11111111
    $SWAGGERED_CLASSES = [
      ErrorModel,
      self
    ]

    load './swagger.rb'

    _swagger = Swag.new(conf)
    json Swagger::Blocks.build_root_json($SWAGGERED_CLASSES)
  end
end
