require 'erb'
require_relative 'algorithm_routes'

# def set_routes(classes: allclasses)
def set_routes
  set :server_settings, timeout: 180
  set :public_folder, File.join(__dir__, '../public')

  set :bind, '0.0.0.0' # Allow all hosts
  set :views, File.join(File.dirname(__FILE__), '..', 'views')

  set :template_engines, {
    # :css=>[],
    # :xml=>[],
    # :js=>[],
    html: [:erb],
    all: [:erb],
    json: []
  }

  get %r{/champion/?} do
    halt erb :homepage
  end

  # ###########################################  SETS
  # ###########################################  SETS
  # ###########################################  SETS
  # DEPRECATED DEPRECATED
  # DEPRECATED DEPRECATED
  # DEPRECATED DEPRECATED
  # DEPRECATED DEPRECATED
  # DEPRECATED DEPRECATED
  # DEPRECATED DEPRECATED

  get '/champion/sets' do
    redirect '/champion/sets/', 307
  end

  get '/champion/sets/', provides: %i[html json jsonld] do
    c = Champion::Core.new
    @sets = c.get_sets
    request.accept.each do |type| # Sinatra::Request::AcceptEntry
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
    @sets = c.get_sets(setid: setid) # sets is a hash
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

    warn 'PARAMS', params.keys
    if params[:title]
      title = params[:title]
      desc = params.fetch(:description, 'No Description')
      email = params.fetch(:email, 'nobody@anonymous.org')
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
    _status, _headers, body = call env.merge('PATH_INFO' => "/champion/sets/#{result}", 'REQUEST_METHOD' => 'GET',
                                             'HTTP_ACCEPT' => request.accept.first.to_s)
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
  # END OF DEPRECATED DEPRECATED
  # END OF DEPRECATED DEPRECATED
  # END OF DEPRECATED DEPRECATED

  # TODO
  # /metrics

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
    if params['resource_identifier'] # for calls from the Web form
      subject = params['resource_identifier']
    else
      payload = JSON.parse(request.body.read)
      subject = payload['resource_identifier']
    end
    champ = Champion::Core.new
    @result = champ.run_assessment(subject: subject, setid: setid)

    request.accept.each do |type|
      case type.to_s
      when 'text/html', 'application/xhtml+xml'
        content_type :html
        data = JSON.parse(@result)
        # Extract the result set and graph
        @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
        @graph = data['@graph']
        # Render the ERB template
        halt erb :evaluation_response
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt @result
      else
        warn "type is #{type}"
        @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
        @graph = data['@graph']
        # Render the ERB template
        halt erb :evaluation_response
      end
    end
    error 406

    result
  end

  # ###########################################  BENCHMARKS
  # ###########################################  BENCHMARKS
  # ###########################################  BENCHMARKS

  # this is the Benchmark API
  get '/champion/assess/benchmark/new' do
    erb :init_benchmark_assessment
  end

  # redirect "/champion/assess/benchmark", 307

  post '/champion/assess/benchmark/' do
    content_type :json
    body = request.body.read # might be empty
    if params['bmid'] # for calls from the Web form
      bmid = params['bmid']
    else
      payload = JSON.parse(body)
      bmid = payload['bmid']
    end

    # methodology:  call GET on BMID, BMID is a FAIRsharing DOI,
    # so call it (eventauly!  Not yet, because we are working with Pablo's BMs files)
    # for now, just call the URL of the benchmark and assume that it is DCAT
    # extract the URIs of the metrics
    # Lookup in FDP Index to get the Tests

    warn "received call to evaluate benchmark #{bmid}"
    if params['resource_identifier'] # for calls from the Web form
      subject = params['resource_identifier']
    else
      payload = JSON.parse(body)
      subject = payload['resource_identifier']
    end
    champ = Champion::Core.new
    #  THIS WILL EVENTUALLY USE the dcat profile in the Accept headers!
    @result = champ.run_benchmark_assessment(subject: subject, bmid: bmid)

    warn "\n\n\n"
    warn @result
    warn "\n\n\n"

    request.accept.each do |type|
      case type.to_s
      when 'text/html', 'application/xhtml+xml'
        content_type :html
        data = JSON.parse(@result)
        # Extract the result set and graph
        @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
        @graph = data['@graph']
        # Render the ERB template
        halt erb :evaluation_response
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt @result
      else
        warn "type is #{type}"
        @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
        @graph = data['@graph']
        # Render the ERB template
        halt erb :evaluation_response
      end
    end
    error 406

    result
  end

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

    warn 'getting testid', testid

    c = Champion::Core.new
    @tests = c.get_tests(testid: testid)
    warn 'got ', @tests.inspect
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
    if params[:openapi] # for calls from the Web form
      api = params[:openapi]
    else
      payload = JSON.parse(request.body.read)
      api = payload['openapi']
    end
    c = Champion::Core.new
    testid = c.add_test(api: api)
    warn 'testid', testid
    # this line retrieves the single new test from the database into the expected structure
    _status, _headers, body = call env.merge('PATH_INFO' => "/champion/tests/#{testid}", 'REQUEST_METHOD' => 'GET',
                                             'HTTP_ACCEPT' => request.accept.first.to_s)
    warn 'testid', env.inspect

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

  ##############################  ALGORITHMS
  ##############################  ALGORITHMS
  ##############################  ALGORITHMS
  ##############################  ALGORITHMS
  ##############################  ALGORITHMS

  #  HUMAN

  # this gives the human drop-down interface
  # REGISTER INIT
  get '/champion/algorithms/new' do
    erb :algorithm_register, layout: :algo_register_layout
  end
  # REGISTER
  post '/champion/algorithms/new' do
    calculation_uri = params['calculation_uri']
    algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: "http://example.org/mock")
    response = algorithm.register
    warn response
    redirect to(algorithm.algorithm_guid), 302  # this returns turtle
  end


  # GET /champion/algorithms/  {algorithm: ALGOID}  --> DCAT
  # GET /champion/algorithms/ALGOID ==> DCAT
  # GET /champion/algorithms/ --> List
  # POST /champion/assess/algorithm/ALGOID

  get %r{/champion/algorithms/?} do
    # get a list of all known champion algos from FDP Index
    # request.accept.each do |type|
    #   case type.to_s
    #   when 'text/json', 'application/json', 'application/ld+json'
    #     content_type :json
    #     halt graph.dump(:jsonld)
    #   else
    #     content_type "text/turtle"
    #     halt graph.dump(:turtle)
    #   end
    # end
    error 406  # should never get here
  end



  get '/champion/algorithms/:algorithmid' do
    # googleid = params[:algorithmid]  # deprecated
    @results_json = Algorithm.retrieve_by_id(algorithm_id: params[:algorithmid])
    request.accept.each do |type|
      case type.to_s
      when 'text/html'
        content_type :html
        halt erb :algorithm_display, layout: :algorithm_layout
      when 'text/json', 'application/json', 'application/ld+json'
        content_type :json
        halt results_json
      end
    end
    error 406
  end


  post '/champion/assess/algorithm/:algorithmid' do
    algo_json = Algorithm.retrieve_by_id(params[:algorithmid])

    unless algo_json
      halt 404, erb(:error, locals: { message: 'valid algorithm id (in the URL, and already registered in the OSTrails Index) is required'}) 
    end
    calculation_uri = algo_json[:scoringfunction]
    guid = params[:guid]
    resultset = params[:resultset]

    halt 400, erb(:error, locals: { message: 'GUID or ResultSet are required in the JSON post body' }) unless resultset || guid
    if guid
      begin
        algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: guid)
        unless algorithm.valid
          halt 406, erb(:error, locals: { message: "The data provided were invalid. Check that you are using a registered algorithm" }) 
        end
        @result = algorithm.process
        halt erb :algorithm_output, layout: :algorithm_layout
      rescue StandardError => e
        halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
      end
    else
      begin
        algorithm = Algorithm.new(calculation_uri: calculation_uri, resultset: resultset)
        unless algorithm.valid
          halt 406, erb(:error, locals: { message: "The data provided were invalid. Check that you are using a registered algorithm" }) 
        end
        @result = algorithm.process
        halt erb :algorithm_output, layout: :algorithm_layout
      rescue StandardError => e
        halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
      end
    end
    error 406
  end

  before do
    # warn 'woohoo'
  end
end
