
def set_routes(classes: allclasses) # $th is the test configuration hash

  set :server_settings, timeout: 180
  set :public_folder, "public"


  get '/' do
    content_type :json
    json Swagger::Blocks.build_root_json(classes)
  end

  post "/evaluate/set/:setid" do
    content_type :json
    id = params[:setid]
    payload = JSON.parse(request.body.read)
    guid = payload["subject"]
    result = Champion::Core.run_evaluation(subject: guid, set: setid)
    result
  end

  post "/tests/:id" do
    id = params[:id]
    payload = JSON.parse(request.body.read)
    guid = payload["subject"]
    #begin
      @result = FAIRTest.send(id,**{guid: guid})
    #rescue
    #  @result = "{}"
    #end
    @result.to_json
  end

  get "/tests/:id" do
    id = params[:id]
    id += "_api"
    #begin
      @result = FAIRTest.send(id)

    #rescue
    #  @result = "{}"
    #end
    @result
  end


  before do
#
  end
  
end
