require 'erb'

# def set_routes(classes: allclasses)
def set_routes()
  set :server_settings, timeout: 180
  set :public_folder, 'public'
  # set :bind, '0.0.0.0'  # Allow all hosts

  set :template_engines, {
    # :css=>[],
    # :xml=>[],
    # :js=>[],
    html: [:erb],
    all: [:erb],
    json: []
  }

  # get '/champion' do
  #   content_type :json
  #   Swagger::Blocks.build_root_json(classes).to_json
  # end


  # ###########################################  SETS
  # ###########################################  SETS
  # ###########################################  SETS

  get '/champion/sets' do
    redirect '/champion/sets/', 307
  end

  get '/champion/sets/', provides: %i[html json jsonld] do
    c = Champion::Core.new
    @sets = c.get_sets
    request.accept.each do |type|  # Sinatra::Request::AcceptEntry
      case type.to_s
      when 'text/html'
        halt erb :listsets
      when 'text/json', 'application/json', 'application/ld+json'
        halt @sets.to_json
      end
    end
    error 406
  end

  get '/champion/sets/:setid' do
    c = Champion::Core.new
    setid = params[:setid]
    @sets = c.get_sets(setid: setid)  # sets is a hash
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        halt erb :showset
      when 'text/json', 'application/json', 'application/ld+json'
        halt @sets.to_json
      end
    end
    error 406
  end

  post '/champion/sets' do
    redirect '/champion/sets/', 307
  end

  post '/champion/sets/' do
    content_type :json
    puts "Request ENV: #{request.env.inspect}"

    warn "PARAMS", params.keys
    if params[:title]
      title = params[:title]
      desc = params.fetch(:description, "No Description")
      email = params.fetch(:email, "nobody@anonymous.org")
      tests = params.fetch(:testid)
    else
      payload = JSON.parse(request.body.read)
      title = payload['title']
      desc = payload['description']
      email = payload['email']
      tests = payload['tests']
    end
    champ = Champion::Core.new
    result = champ.add_set(title: title, desc: desc, email: email, tests: tests)
    _status, _headers, body = call env.merge("PATH_INFO" => "/champion/sets/#{result}", 'REQUEST_METHOD' => "GET", 'HTTP_ACCEPT' => request.accept.first.to_s)
    request.accept.each do |type|
      warn "ACCEPT REQ #{type}"
      case type.to_s
      when 'text/html'
        content_type :html
        halt body
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt body
      end
    end
    error 406
  end

    # ###########################################  ASSESSMENTS
    # ###########################################  ASSESSMENTS
    # ###########################################  ASSESSMENTS


  get '/champion/sets/:setid/assessments' do
    id = params[:setid]
    redirect "/champion/sets/#{id}/assessments/", 307
  end

  get '/champion/sets/:setid/assessments/' do
    # List of assessments from that set id
  end

  get '/champion/sets/:setid/assessments/new' do
    @setid = params[:setid]
    halt erb :new_evaluation
  end

  post '/champion/sets/:setid/assessments' do
    id = params[:setid]
    redirect "/champion/sets/#{id}/assessments/", 307
  end

  post '/champion/sets/:setid/assessments/' do
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
    result = champ.run_assessment(subject: subject, setid: setid)
    result
  end

  # get '/sets/:setid/assessments/:assid' do
  #   content_type :json
  #   # setid = params[:setid]
  #   # evalid = params[:evalid]
  #   # result = champ.run_evaluation(subject: subject, setid: setid)
  #   # #  TODO  SET Location Header!!!!!!!!!!!!!!!!
  #   # result
  # end


  # ###########################################  TESTS
  # ###########################################  TESTS
  # ###########################################  TESTS

  get '/champion/tests' do
    redirect '/champion/tests/', 307
  end
  get '/champion/tests/new' do
    redirect '/champion/tests/new/', 307
  end

  get '/champion/tests/new/', provides: %i[html] do
    halt erb :new_test
  end

  get '/champion/tests/', provides: %i[html json jsonld] do
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

  get '/champion/tests/:testid' do
    testid = params[:testid]

    warn "getting testid", testid

    c = Champion::Core.new
    @tests = c.get_tests(testid: testid)
    warn "got ", @tests.inspect
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        content_type :html
        halt erb :showtest
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt @tests.first.to_json
      end
    end
    error 406
  end

  post '/champion/tests' do
    redirect '/champion/tests/', 307
  end

  post '/champion/tests/' do
    if params[:openapi]  # for calls from the Web form
      api = params[:openapi] 
    else
      payload = JSON.parse(request.body.read)
      api = payload['openapi']
    end
    c = Champion::Core.new
    testid = c.add_test(api: api)
    warn "testid", testid
    # this line retrieves the single new test from the database into the expected structure
    _status, _headers, body = call env.merge("PATH_INFO" => "/champion/tests/#{testid}", 'REQUEST_METHOD' => "GET", 'HTTP_ACCEPT' => request.accept.first.to_s)
    warn "testid", env.inspect

    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        content_type :html
        halt body
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt body
      end
    end
    error 406
  end

  # ####################################################################################
  # ####################################################################################

  before do
    # warn 'woohoo'
  end
end
