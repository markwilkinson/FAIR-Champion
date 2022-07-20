
def set_routes(classes: allclasses) # $th is the test configuration hash
  get '/test2' do
    json Swagger::Blocks.build_root_json(classes)
  end
  get '/' do
    json Swagger::Blocks.build_root_json(classes)
  end
  $th.each do |guid, val|
    get "/#{val['title']}" do
      json Swagger::Blocks.build_root_json(classes)
    end
  end
end
