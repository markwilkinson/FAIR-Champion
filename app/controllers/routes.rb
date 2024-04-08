require 'erb'

def set_routes(classes: allclasses)
  set :server_settings, timeout: 180
  set :public_folder, 'public'

  set :template_engines, {
    # :css=>[],
    # :xml=>[],
    # :js=>[],
    html: [:erb],
    all: [:erb],
    json: []
  }

  get '/' do
    content_type :json
    Swagger::Blocks.build_root_json(classes).to_s
  end

  get '/sets' do
    redirect '/sets/'
  end

  get '/sets/', provides: %i[html json jsonld] do
    c = Champion::Core.new
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
    c = Champion::Core.new
    setid = params[:setid]
    @sets = c.get_sets(setid: setid)
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
    redirect '/sets/'
  end

  post '/sets/' do
    content_type :json
    warn "PARAMS", params.keys
    if params[:title]
      title = params[:title]
      desc = params.fetch(:description, "No Description")
      email = params.fetch(:email, "nobody@anonymous.org")
      tests = params.fetch(:testid)
      halt
    else
      payload = JSON.parse(request.body.read)
      title = payload['title']
      desc = payload['description']
      email = payload['email']
      tests = payload['tests']
    end
    champ = Champion::Core.new
    result = champ.add_set(title: title, desc: desc, email: email, tests: tests)
    result
  end

  get '/sets/:setid/evaluations' do
    id = params[:setid]
    redirect "/sets/#{id}/evaluations/"
  end

  get '/sets/:setid/evaluations/' do
    # List of evaluations from that set id
  end
  get '/sets/:setid/evaluations/new' do
    @setid = params[:setid]
    halt erb :new_evaluation
  end


  post '/sets/:setid/evaluations' do
    id = params[:setid]
    redirect "/sets/#{id}/evaluations/"
  end

  post '/sets/:setid/evaluations/' do
    content_type :json
    setid = params[:setid]
    warn "received call to evaluate #{setid}"
    if params[:subject]  # for calls from the Web form
      subject = params[:subject] 
    else
      payload = JSON.parse(request.body.read)
      subject = payload['subject']
    end
    champ = Champion::Core.new
    result = champ.run_evaluation(subject: subject, setid: setid)
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


  # ###########################################

  get '/tests' do
    redirect '/tests/'
  end

  get '/tests/', provides: %i[html json jsonld] do
    c = Champion::Core.new
    @tests = c.get_tests
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :listtests
      when 'text/json', 'application/json', 'application/ld+json'
        halt @tests.to_json
      end
    end
    error 406
  end

  get '/tests/:testid' do
    c = Champion::Core.new
    testid = params[:testid]
    @tests = c.get_tests(testid: testid)
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :listsets
      when 'text/json', 'application/json', 'application/ld+json'
        halt @tests.to_json
      end
    end
    error 406
  end

  post '/tests' do
    redirect '/tests/'
  end

  post '/tests/' do
    content_type :json
    if params[:openapi]  # for calls from the Web form
      api = params[:openapi] 
    else
      payload = JSON.parse(request.body.read)
      api = payload['openapi']
    end
    c = Champion::Core.new
    @tests = c.add_test(api: api)
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :listtests
      when 'text/json', 'application/json', 'application/ld+json'
        halt @tests.to_json
      end
    end

  end

  # ####################################################################################
  # ####################################################################################

  before do
    warn 'woohoo'
  end
end
