def set_routes(classes: allclasses) 
  set :server_settings, timeout: 180
  set :public_folder, 'public'

  get '/' do
    content_type :json
    json Swagger::Blocks.build_root_json(classes)
  end

  post '/evaluate/set/:setid' do
    content_type :json
    setid = params[:setid]
    warn "received call to evaluate #{setid}"
    payload = JSON.parse(request.body.read)
    subject = payload['subject']
    champ = Champion::Core.new
    result = champ.run_evaluation(subject: subject, setid: setid)
    result
  end

  before do
  end
end
