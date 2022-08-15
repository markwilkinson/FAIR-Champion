
def set_routes(classes: allclasses) # $th is the test configuration hash
  get '/' do
    json Swagger::Blocks.build_root_json(classes)
  end
  # $th.each do |guid, val|
  #   get "fair_maturity_test/#{val['title']}" do
  #     json Swagger::Blocks.build_root_json(classes)
  #   end
  # end
end
