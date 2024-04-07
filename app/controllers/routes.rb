require 'sinatra/contrib'
require 'erb'


def set_routes(classes: allclasses) 
  set :server_settings, timeout: 180
  set :public_folder, 'public'

  set :template_engines, {
  # :css=>[],
  # :xml=>[],
  # :js=>[],
  :html=>[:erb],
  :all=>[:erb],
  :json=>[]
}
  get '/' do
    content_type :json
    json Swagger::Blocks.build_root_json(classes)
  end

  get '/sets' do
    redirect '/sets/'
  end

  get '/sets/', provides: %i[html json jsonld] do
    c =Champion::Core.new()
    @sets = c.get_sets
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :listsets
      when 'text/json', 'application/json', 'application/ld+json'
        halt @sets.to_json
      end
    end
    error 406    
  end


  get '/sets/:setid' do
    c =Champion::Core.new()
    setid = params[:setid]
    @sets = c.get_sets(setid: setid )
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :listsets
      when 'text/json', 'application/json', 'application/ld+json'
        halt @sets.to_json
      end
    end
    error 406    
  end

  post '/sets' do
    # redirect to /sets/
  end

  post '/sets/' do
    content_type :json
    # create a new set from a POST of set ids
    # metadata
    # title
    # description
    # author
    # setid (maybe from SLUG?)
    # tests []
    #
    # return setid
  end

  get '/sets/:setid/evaluations' do
    # redirect to /evaluations/
  end

  get '/sets/:setid/evaluations/' do
    # List of evaluations from that set id
  end

  post '/sets/:setid/evaluations' do
    # redirect to /evaluations/
  end

  post '/sets/:setid/evaluations/' do
    content_type :json
    setid = params[:setid]
    warn "received call to evaluate #{setid}"
    payload = JSON.parse(request.body.read)
    subject = payload['subject']
    champ = Champion::Core.new
    result = champ.run_evaluation(subject: subject, setid: setid)
    #  TODO  SET Location Header!!!!!!!!!!!!!!!!
    result
  end

  get '/sets/:setid/evaluations/:evalid' do
    content_type :json
    setid = params[:setid]
    evalid = params[:evalid]
    # result = champ.run_evaluation(subject: subject, setid: setid)
    # #  TODO  SET Location Header!!!!!!!!!!!!!!!!
    # result
  end

  before do
    warn 'woohoo'
  end
end
