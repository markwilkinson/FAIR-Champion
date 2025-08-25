require 'erb'
require_relative 'algorithm_routes'

def set_routes
  set :server_settings, timeout: 180
  set :public_folder, File.join(__dir__, '../public')

  set :bind, '0.0.0.0' # Allow all hosts
  set :views, File.join(File.dirname(__FILE__), '..', 'views')

  set :template_engines, {
    html: [:erb],
    all: [:erb],
    json: []
  }

  get %r{/champion/api/?} do
    redirect '/champion/championAPI.yaml', 307
  end

  get %r{/champion/?} do
    halt erb :homepage
  end

  # ###########################################  TESTS
  # ###########################################  TESTS
  # ###########################################  TESTS

  get '/champion/tests' do
    redirect '/champion/tests/', 307
  end

  get '/champion/tests/', provides: [:html, :json, 'application/ld+json'] do
    c = Champion::Core.new
    @tests = c.get_tests

    case content_type
    when %r{text/html}
      halt erb :listtests_output, layout: :listtests_layout
    else
      halt @tests.to_json
    end
  end

  get '/champion/tests/:testid', provides: [:html, :json, 'application/ld+json'] do
    testid = params[:testid]

    warn 'getting testid', testid

    c = Champion::Core.new
    @tests = c.get_tests(testid: testid)
    warn 'got ', @tests.inspect

    case content_type
    when %r{text/html}
      halt erb :showtest
    else
      halt @tests.first.to_json
    end
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
    halt erb :algorithm_register, layout: :algorithm_register_layout
  end
  # REGISTER
  post '/champion/algorithms/new' do
    calculation_uri = params['calculation_uri']
    warn "registering #{calculation_uri}"
    algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: 'http://example.org/mock')
    algorithm.register
    sleep 10 # need time for the FDP index to ingest, then we can redirect to pull info from the sparql endpoint

    redirect to("#{algorithm.algorithm_guid}/display"), 302 # algorithm's guid returns turtle
  end


  get %r{/champion/algorithms/?}, provides: [:html, :json, 'application/ld+json'] do
    @list = Algorithm.list
    # list[identifier] = [title, function]
    # get a list of all known champion algos from FDP Index

    case content_type
    when %r{application/json} || %r{application/ld+json}
      content_type :json
      halt @list.to_json
    else
      halt erb :_algo_list, layout: :algorithm_layout
    end
  end

  get '/champion/algorithms/:algorithmid/display', provides: [:html] do
    calculation_uri = Algorithm.retrieve_by_id(algorithm_id: params[:algorithmid])
    if calculation_uri == false
      halt 406,
           erb(:error,
               locals: { message: 'The server was unable to find that algorithm.  This may be a temporary problem' })
    end
    warn "retrieved calc uri is #{calculation_uri}"
    algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: 'http://example.org/mock')
    @dcat = algorithm.gather_metadata
    halt erb :algorithm_display, layout: :algorithm_layout
  end

  get '/champion/algorithms/:algorithmid', provides: [:html, :json, 'text/turtle', 'application/ld+json'] do
    calculation_uri = Algorithm.retrieve_by_id(algorithm_id: params[:algorithmid])
    if calculation_uri == false
      halt 406,
           erb(:error,
               locals: { message: 'The server was unable to find that algorithm.  This may be a temporary problem' })
    end
    warn "retrieved calc uri is #{calculation_uri}"
    algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: 'http://example.org/mock')
    @dcat = algorithm.gather_metadata  # @dcat is an rdf::graph object
    content_type = 'text/turtle'
    case content_type
    when %r{text/html}
      halt erb :algorithm_display, layout: :algorithm_layout
    when %r{application/json} || %r{application/ld+json}
      halt @dcat.dump(:jsonld)
    when %r{text/turtle}
      halt @dcat.dump(:turtle)
    end
    halt 406
  end

  get '/champion/assess/algorithms/new' do
    @list = Algorithm.list
    # list[identifier] = [title, function]
    # get a list of all known champion algos from FDP Index

    halt erb :algorithm_initiate, layout: :algorithm_initiate_layout
  end

  post '/champion/assess/algorithm' do
    calculation_uri = params['calculation_uri']
    abort 'no calc uri' unless calculation_uri
    algoid = calculation_uri.match(%r{/\w/([^/]+)})[1]
    new_env = request.env.merge('PATH_INFO' => "/champion/assess/algorithm/#{algoid}")
    call(new_env)
  end

  get '/champion/assess/algorithm/:algorithmid', provides: [:json] do
    content_type :json
    openapi_spec = Algorithm.generate_assess_algorithm_openapi(algorithmid: params[:algorithmid])
    halt openapi_spec.to_json
  end
  get '/champion/assess/algorithm/:algorithmid/' do
    redirect "/champion/assess/algorithm/#{params[:algorithmid]}", 301
  end

  post '/champion/assess/algorithm/:algorithmid', provides: [:html, :json, 'application/ld+json'] do
    scoringfunction = Algorithm.retrieve_by_id(algorithm_id: params[:algorithmid])

    unless scoringfunction
      halt 404,
          erb(:error,
              locals: { message: 'need valid algorithm id (in the URL, and already registered in the OSTrails Index) is required' })
    end
    calculation_uri = scoringfunction
    guid = nil
    resultset = nil
    if request.content_type == 'application/json'
      begin
        body = JSON.parse(request.body.read)
        # Check if the JSON body contains guid or resultset keys
        if body.is_a?(Hash) && (body['guid'] || body['resultset'])
          guid = body['guid']
          resultset = body['resultset']
        else
          # Treat the entire JSON body as the resultset
          resultset = body
        end
      rescue JSON::ParserError => e
        halt 400, erb(:error, locals: { message: "Invalid JSON: #{e.message}" })
      end
    else
      # Handle form data (urlencoded or multipart)
      guid = params[:guid]
      resultset = params[:resultset]

      warn "incoming params: #{params.inspect}\n\n\n"
      if params[:file] && !params[:file].empty? && params[:file][:tempfile]
        begin
          # Read the uploaded file as a string
          resultset ||= params[:file][:tempfile].read
          # Optionally validate that it's valid JSON-LD
          JSON.parse(resultset) # This raises an error if invalid, but doesn't store the parsed result
        rescue JSON::ParserError => e
          halt 400, erb(:error, locals: { message: "Invalid JSON in uploaded file: #{e.message}" })
        end
      end
    end

    unless resultset || guid
      halt 400,
          erb(:error,
              locals: { message: 'GUID or ResultSet (or file upload) are required' })
    end

    if resultset
    #  begin
        algorithm = Algorithm.new(calculation_uri: calculation_uri, resultset: resultset)
        unless algorithm.valid
          halt 406,
              erb(:error,
                  locals: { message: 'The data provided were invalid. Check that you are using a registered algorithm' })
        end
        @result = algorithm.process # result has 5 components, including resultset as jsonld string
        # @rdfgraph = algorithm.generate_execution_output_rdf(output: @result, algorithmid: params[:algorithmid])
    #  rescue StandardError => e
    #    halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
    #  end
    else guid
    #  begin
        algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: guid)
        unless algorithm.valid
          halt 406,
              erb(:error,
                  locals: { message: 'The data provided were invalid. Check that you are using a registered algorithm' })
        end
        @result = algorithm.process  # result has 5 components, including resultset as jsonld string
        # @rdfgraph = algorithm.generate_execution_output_rdf(output: @result, algorithmid: params[:algorithmid])
    #  rescue StandardError => e
    #    halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
    #  end
    end
    warn "trying to match #{content_type}"

    case content_type
    when %r{text/html}
      halt erb :algorithm_execution_output, layout: :algorithm_execution_layout
    when %r{application/json} || %r{application/ld+json}
      halt @rdfgraph.dump(:jsonld)
    when %r{text/turtle}
      halt @rdfgraph.dump(:turtle)
    end
    halt 406
  end

  before do
    # warn 'woohoo'
  end
end



  # post '/champion/assess/algorithm/:algorithmid', provides: [:html, :json, 'application/ld+json'] do
  #   scoringfunction = Algorithm.retrieve_by_id(algorithm_id: params[:algorithmid])

  #   unless scoringfunction
  #     halt 404,
  #          erb(:error,
  #              locals: { message: 'need valid algorithm id (in the URL, and already registered in the OSTrails Index) is required' })
  #   end
  #   calculation_uri = scoringfunction
  #   guid = params[:guid]
  #   resultset = params[:resultset]

  #   unless resultset || guid
  #     halt 400,
  #          erb(:error,
  #              locals: { message: 'GUID or ResultSet are required in the JSON post body' })
  #   end
  #   if guid
  #     begin
  #       algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: guid)
  #       unless algorithm.valid
  #         halt 406,
  #              erb(:error,
  #                  locals: { message: 'The data provided were invalid. Check that you are using a registered algorithm' })
  #       end
  #       @result = algorithm.process
  #       halt erb :algorithm_execution_output, layout: :algorithm_execution_layout
  #     rescue StandardError => e
  #       halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
  #     end
  #   else
  #     begin
  #       algorithm = Algorithm.new(calculation_uri: calculation_uri, resultset: resultset)
  #       unless algorithm.valid
  #         halt 406,
  #              erb(:error,
  #                  locals: { message: 'The data provided were invalid. Check that you are using a registered algorithm' })
  #       end
  #       @result = algorithm.process
  #       halt erb :algorithm_execution_output, layout: :algorithm_execution_layout
  #     rescue StandardError => e
  #       halt 500, erb(:error, locals: { message: "Error processing algorithm: #{e.message}" })
  #     end
  #   end
  # end


# ###########################################  SETS
# ###########################################  SETS
# ###########################################  SETS
# DEPRECATED DEPRECATED
# DEPRECATED DEPRECATED
# DEPRECATED DEPRECATED
# DEPRECATED DEPRECATED
# DEPRECATED DEPRECATED
# DEPRECATED DEPRECATED

# get '/champion/sets' do
#   redirect '/champion/sets/', 307
# end

# get '/champion/sets/', provides: [:html, :json, 'application/ld+json'] do
#   c = Champion::Core.new
#   @sets = c.get_sets

#   case content_type
#   when %r{text/html}
#     halt erb :listsets
#   when  %r{application/json} || %r{application/ld+json}
#     halt @sets.to_json
#   end
# end

# get '/champion/sets/:setid', provides: [:html, :json, 'application/ld+json'] do
#   c = Champion::Core.new
#   setid = params[:setid]
#   @sets = c.get_sets(setid: setid) # sets is a hash

#   case content_type
#   when %r{text/html}
#     halt erb :showset
#   when  %r{application/json} || %r{application/ld+json}
#     halt @sets.to_json
#   end
# end

# post '/champion/sets' do
#   redirect '/champion/sets/', 307
# end

# post '/champion/sets/', provides: [:html, :json, 'application/ld+json'] do
#   content_type :json
#   puts "Request ENV: #{request.env.inspect}"

#   warn 'PARAMS', params.keys
#   if params[:title]
#     title = params[:title]
#     desc = params.fetch(:description, 'No Description')
#     email = params.fetch(:email, 'nobody@anonymous.org')
#     tests = params.fetch(:testid)
#   else
#     payload = JSON.parse(request.body.read)
#     title = payload['title']
#     desc = payload['description']
#     email = payload['email']
#     tests = payload['tests']
#   end
#   champ = Champion::Core.new
#   result = champ.add_set(title: title, desc: desc, email: email, tests: tests)
#   _status, _headers, body = call env.merge('PATH_INFO' => "/champion/sets/#{result}", 'REQUEST_METHOD' => 'GET',
#                                            'HTTP_ACCEPT' => request.accept.first.to_s)

#   case content_type
#   when 'text/html'
#     halt body
#   when   'application/json', 'application/ld+json'
#     halt body
#   end
# end
# END OF DEPRECATED DEPRECATED
# END OF DEPRECATED DEPRECATED
# END OF DEPRECATED DEPRECATED

# TODO
# /metrics

# ###########################################  ASSESSMENTS
# ###########################################  ASSESSMENTS
# ###########################################  ASSESSMENTS
# DEPRECATED
# get '/champion/sets/:setid/assessments' do
#   id = params[:setid]
#   redirect "/champion/sets/#{id}/assessments/", 307
# end

# get '/champion/sets/:setid/assessments/' do
#   # List of assessments from that set id
# end

# get '/champion/sets/:setid/assessments/new', provides: [:html, :json, 'application/ld+json'] do
#   @setid = params[:setid]
#   halt erb :new_evaluation
# end

# post '/champion/sets/:setid/assessments', provides: [:html, :json, 'application/ld+json'] do
#   id = params[:setid]
#   redirect "/champion/sets/#{id}/assessments/", 307
# end

# post '/champion/sets/:setid/assessments/', provides: [:html, :json, 'application/ld+json'] do
#   content_type :json
#   setid = params[:setid]
#   warn "received call to evaluate #{setid}"
#   if params['resource_identifier'] # for calls from the Web form
#     subject = params['resource_identifier']
#   else
#     payload = JSON.parse(request.body.read)
#     subject = payload['resource_identifier']
#   end
#   champ = Champion::Core.new
#   @result = champ.run_assessment(subject: subject, setid: setid)

#   case content_type
#   when %r{text/html}
#     data = JSON.parse(@result)
#     # Extract the result set and graph
#     @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
#     @graph = data['@graph']
#     # Render the ERB template
#     halt erb :evaluation_response
#   when %r{application/json} || %r{application/ld+json}
#     halt @result
#   else
#     @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
#     @graph = data['@graph']
#     # Render the ERB template
#     halt erb :evaluation_response
#   end

#   result
# end

# ###########################################  BENCHMARKS
# ###########################################  BENCHMARKS
# ###########################################  BENCHMARKS

# this is the Benchmark API
# get '/champion/assess/benchmark/new' do
#   erb :init_benchmark_assessment
# end

# # redirect "/champion/assess/benchmark", 307

# post '/champion/assess/benchmark/', provides: [:html, :json, 'application/ld+json'] do
#   body = request.body.read # might be empty
#   if params['bmid'] # for calls from the Web form
#     bmid = params['bmid']
#   else
#     payload = JSON.parse(body)
#     bmid = payload['bmid']
#   end

# methodology:  call GET on BMID, BMID is a FAIRsharing DOI,
# so call it (eventauly!  Not yet, because we are working with Pablo's BMs files)
# for now, just call the URL of the benchmark and assume that it is DCAT
# extract the URIs of the metrics
# Lookup in FDP Index to get the Tests

#   warn "received call to evaluate benchmark #{bmid}"
#   if params['resource_identifier'] # for calls from the Web form
#     subject = params['resource_identifier']
#   else
#     payload = JSON.parse(body)
#     subject = payload['resource_identifier']
#   end
#   champ = Champion::Core.new
#   #  THIS WILL EVENTUALLY USE the dcat profile in the Accept headers!
#   @result = champ.run_benchmark_assessment(subject: subject, bmid: bmid)

#   warn "\n\n\n"
#   warn @result
#   warn "\n\n\n"

#   case content_type
#   when %r{text/html}
#     data = JSON.parse(@result)
#     # Extract the result set and graph
#     @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
#     @graph = data['@graph']
#     # Render the ERB template
#     halt erb :evaluation_response
#   when %r{application/json}
#     halt @result
#   when %r{application/ld+json}
#     halt @result
#   else
#     @result_set = data['@graph'].find { |node| node['@type'].include?('ftr:TestResultSet') }
#     @graph = data['@graph']
#     # Render the ERB template
#     halt erb :evaluation_response
#   end

#   result
# end

# post '/champion/tests' do
#   redirect '/champion/tests/', 307
# end

# post '/champion/tests/', provides: [:html, :json, 'application/ld+json'] do
#   if params[:openapi] # for calls from the Web form
#     api = params[:openapi]
#   else
#     payload = JSON.parse(request.body.read)
#     api = payload['openapi']
#   end
#   c = Champion::Core.new
#   testid = c.add_test(api: api)
#   warn 'testid', testid
#   # this line retrieves the single new test from the database into the expected structure
#   _status, _headers, body = call env.merge('PATH_INFO' => "/champion/tests/#{testid}", 'REQUEST_METHOD' => 'GET',
#                                            'HTTP_ACCEPT' => request.accept.first.to_s)
#   warn 'testid', env.inspect

#   case content_type
#   when %r{text/html}
#     halt body
#   when  %r{application/json}
#     halt body
#   when %r{application/ld+json}
#     halt body
#   when %r{text/turtle}
#     halt body
#   end
#   halt 406
# end
