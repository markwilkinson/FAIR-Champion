require 'erb'
require 'stringio'

module Champion
  class ChampionApp < Sinatra::Base
    # Configures Sinatra routes and settings for the Champion application, handling
    # test listings, algorithm registration, display, and assessment execution.
    # @note This file assumes a Sinatra application context and depends on Algorithm and Champion::Core classes.
    def self.set_routes
      puts "Calling set_routes at #{Time.now}"
      # Sets the server timeout to 180 seconds.
      set :server_settings, timeout: 180
      # Sets the public folder for static assets.
      set :public_folder, File.join(__dir__, '../public')

      # Allows binding to all network interfaces.
      set :bind, '0.0.0.0'
      # Sets the views directory for ERB templates.
      set :views, File.join(File.dirname(__FILE__), '..', 'views')

      # Configures template engines for different content types.
      set :template_engines, {
        html: [:erb],
        all: [:erb],
        json: []
      }

      # Redirects requests to the Champion API specification.
      # @return [void] Redirects to '/champion/championAPI.yaml' with a 307 status.
      # @example
      #   # GET /champion/api/
      get %r{/champion/api/?} do
        redirect '/champion/championAPI.yaml', 307
      end

      # Renders the Champion homepage.
      # @return [String] The rendered ERB template for the homepage.
      # @example
      #   # GET /champion/
      get %r{/champion/?} do
        halt erb :homepage
      end

      # ###########################################  TESTS
      # ###########################################  TESTS
      # ###########################################  TESTS

      # Redirects requests for '/champion/tests' to '/champion/tests/'.
      # @return [void] Redirects to '/champion/tests/' with a 301 status.
      get '/champion/tests' do
        redirect '/champion/tests/', 301
      end

      # Lists all tests, supporting multiple formats.
      # @return [String] HTML, JSON, or JSON-LD representation of the test list.
      # @example
      #   # GET /champion/tests/
      #   # Returns HTML list or JSON/JSON-LD data
      get '/champion/tests/', provides: [:html, :json, 'application/ld+json'] do
        c = Champion::Core.new
        @tests = c.get_tests # returns array of Champion::Test objects
        # puts "Tests: #{@tests.inspect}"
        case content_type
        when %r{text/html}
          halt erb :listtests_output, layout: :listtests_layout
        else
          halt @tests.to_json
        end
      end

      # Displays a specific test by its ID, supporting multiple formats.
      # @param testid [String] The identifier of the test to display.
      # @return [String] HTML, JSON, or JSON-LD representation of the test.
      # @example
      #   # GET /champion/tests/test1
      #   # Returns HTML or JSON/JSON-LD data for test1
      get '/champion/tests/:testid', provides: [:html, :json, 'application/ld+json'] do
        testid = params[:testid]
        warn 'getting testid', testid

        c = Champion::Core.new
        @tests = c.get_tests(testid: testid)
        # warn 'got ', @tests.inspect

        case content_type
        when %r{text/html}
          halt erb :listtests_output, layout: :listtests_layout
        else
          halt @tests.first.to_json
        end
      end

      post '/champion/test-execution-proxy' do
        endpoint = params[:endpoint]
        halt 400, { error: 'Missing endpoint' }.to_json unless endpoint && endpoint.strip != ''

        submission_mode = params[:submission_mode] || 'guid'

        # ────────────────────────────────────────────────
        # Prepare arguments for Champion::Core#proxy_test
        # ────────────────────────────────────────────────

        core = Champion::Core.new

        if submission_mode == 'metadata_file'
          # Multipart file upload path

          file = params[:metadata_file] || params[:file] # Accept either name from your form
          halt 400, { error: 'No metadata file uploaded' }.to_json unless file && file[:tempfile] && file[:filename]

          # Basic validation: filename should end with .json, content-type json-ish
          unless file[:filename].to_s.downcase.end_with?('.json') || file[:type] =~ /json/i
            halt 400, { error: 'File should be a JSON file (e.g. ro-crate-metadata.json)' }.to_json
          end

          # Optional: read and validate JSON early (prevents sending invalid data upstream)
          begin
            metadata_content = file[:tempfile].read
            JSON.parse(metadata_content)  # raises if not valid JSON
            file[:tempfile].rewind        # important! rewind so RestClient can read it again
          rescue JSON::ParserError
            halt 400, { error: 'Uploaded file is not valid JSON' }.to_json
          end

          # Forward as multipart/form-data with the exact field name 'file'
          payload = { file: file } # RestClient handles Tempfile → multipart upload automatically

          headers = {
            'Accept' => 'application/json, application/ld+json',
            'User-Agent' => 'Champion-Test-Proxy/1.0'
          }

          # Forward Authorization if present (as per YAML: optional header for private mode)
          if env['HTTP_AUTHORIZATION'] && env['HTTP_AUTHORIZATION'].strip != ''
            headers['Authorization'] = env['HTTP_AUTHORIZATION']
          end

          begin
            response = RestClient.post(
              endpoint,
              payload,
              headers.merge(content_type: 'multipart/form-data') # RestClient adds boundary automatically
            )
            raw_output = response.body
            status response.code
          rescue RestClient::ExceptionWithResponse => e
            raw_output = e.response.body || '{}'
            status e.http_code || 502
            # You can log e.response.headers[:location] here if 202
          rescue StandardError => e
            halt 500, { error: "Failed to submit to remote API: #{e.message}" }.to_json
          end
        else
          # ────────────────────────────────────────────────
          # Classic GUID / resource_identifier path
          # ────────────────────────────────────────────────
          resource_identifier = params[:resource_identifier]&.strip
          unless resource_identifier && resource_identifier != ''
            halt 400,
                 { error: 'Missing resource_identifier' }.to_json
          end

          # Reuse the original method — this is the key part you pointed out
          raw_output = core.proxy_test(
            endpoint: endpoint,
            resource_identifier: resource_identifier
          )
        end

        # At this point we have raw_output (string) — same as original route

        # ────────────────────────────────────────────────
        # Parse & prepare for view (same as original)
        # ────────────────────────────────────────────────

        begin
          @result = raw_output
          @testresult = Champion::TestResult.test_output_parser(output: @result)

          raise 'Test execution data not found or invalid' unless @testresult.is_a?(Champion::TestResult)

          # If we got here → parsing succeeded

          # Decide response format
          request.accept.each do |type|
            case type.to_s
            when %r{text/html} || %r{application/xhtml+xml}
              content_type :html

              # # Populate instance variables your :testresult ERB expects
              # # (adjust names if your template uses different ones)
              # @graph          = @testresult.graph          # assuming it has this
              # #@test_execution = @testresult.execution # or find via @graph
              # @test           = @testresult.test
              # @test_result    = @testresult.result
              # @result_value   = @testresult.result_value   # or however you access it

              # If you still need the manual find logic as fallback:
              # data = begin
              #   JSON.parse(@result)
              # rescue StandardError
              #   {}
              # end
              # @test_execution ||= data.dig('@graph')&.find { |g| g['@type'] == 'ftr:TestExecutionActivity' }
              # ... etc.

              halt erb :testresult
            when %r{application/json} || %r{application/ld+json} || %r{text/json}
              content_type :json
              halt @result # raw JSON-LD string

            else
              # fallback
            end
          end

          # No acceptable type
          error 406
        rescue JSON::ParserError, StandardError => e
          # This is where your "undefined method `value' for nil" was probably coming from
          # → safer handling now
          status 500
          content_type :json
          { error: "Result parsing failed: #{e.message}", raw_output: raw_output[0..500] }.to_json
        end
      end

      # post '/champion/test-execution-proxy', provides: [:html, :json, 'application/ld+json'] do
      #   if params['resource_identifier']
      #     resource_identifier = params['resource_identifier']
      #     endpoint = params['endpoint']
      #   else
      #     payload = JSON.parse(request.body.read)
      #     resource_identifier = payload['resource_identifier']
      #     endpoint = payload['endpoint']
      #   end

      #   c = Champion::Core.new
      #   warn "now testing #{resource_identifier} with endpoint #{endpoint}"
      #   @result = c.proxy_test(endpoint: endpoint, resource_identifier: resource_identifier)
      #   @testresult = Champion::TestResult.test_output_parser(output: @result) # Champion::TestResult object with all fields populated, including @graph with the RDF graph of the test execution result
      #   unless @testresult.is_a?(Champion::TestResult)
      #     halt erb(:error, locals: { message: "Test execution data not found or invalid #{@testresult.inspect}" })
      #   end

      #   if request.accept?('text/html') || request.accept?('application/xhtml+xml')
      #     content_type :html
      #     halt erb :testresult
      #   else
      #     # Assume JSON/LD — most permissive path
      #     content_type 'application/ld+json'
      #     halt @result
      #   end
      #   error 406
      # end

      # ###########################################  ALGORITHMS
      # ###########################################  ALGORITHMS
      # ###########################################  ALGORITHMS

      # Renders a form for registering a new algorithm.
      # @return [String] The rendered ERB template for algorithm registration.
      # @example
      #   # GET /champion/algorithms/new
      get '/champion/algorithms/new' do
        halt erb :algorithm_register, layout: :algorithm_register_layout
      end

      # Registers a new algorithm using a provided calculation URI.
      # @param calculation_uri [String] The Google Spreadsheet URI for the algorithm.
      # @return [void] Redirects to the algorithm display page after registration.
      # @raise [Sinatra::BadRequest] If the calculation URI is invalid.
      # @note Includes a 10-second sleep to allow FDP index ingestion; consider replacing with retry logic post-review.
      # @example
      #   # POST /champion/algorithms/new
      #   # Form data: calculation_uri=https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
      post '/champion/algorithms/new' do
        calculation_uri = params['calculation_uri']
        unless calculation_uri =~ %r{docs\.google\.com/spreadsheets}
          render_error(400,
                       'Invalid calculation URI; must be a Google Spreadsheet URL')
        end
        warn "registering #{calculation_uri}"
        algorithm = Algorithm.new(calculation_uri: calculation_uri, guid: 'http://example.org/mock') # mock is replaced when object is finished
        algorithm.register
        sleep 10 # TODO: Replace with retry mechanism to poll FDP index for ingestion
        algorithmpath = URI(algorithm.algorithm_guid).path
        warn "AlgoPath is #{algorithmpath}"
        redirect to("#{algorithmpath}/display"), 302
      end

      # Displays a specific algorithm’s metadata in HTML format.
      # @param algorithmid [String] The identifier of the algorithm.
      # @return [String] The rendered ERB template for algorithm display.
      # @raise [Sinatra::NotFound] If the algorithm ID is not found.
      # @example
      #   # GET /champion/algorithms/u/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w/display
      get '/champion/algorithms/*/display', provides: [:html] do
        algorithmid = params[:splat].first
        algorithm = fetch_algorithm(algorithmid)
        @dcat = algorithm.gather_metadata
        halt erb :algorithm_display, layout: :algorithm_layout
      end

      # Lists all registered algorithms, supporting multiple formats.
      # @return [String] HTML, JSON, or JSON-LD representation of the algorithm list.
      # @example
      #   # GET /champion/algorithms/
      #   # Returns HTML list or JSON/JSON-LD data
      get %r{/champion/algorithms/?}, provides: [:html, :json, 'application/ld+json'] do
        @list = Algorithm.list
        case content_type
        when %r{application/json} || %r{application/ld+json}
          content_type :json
          halt @list.to_json
        else
          halt erb :_algo_list, layout: :algorithm_layout
        end
      end

      # Retrieves a specific algorithm’s metadata, supporting multiple formats.
      # @param algorithmid [String] The identifier of the algorithm.
      # @return [String] HTML, JSON, JSON-LD, or Turtle representation of the algorithm metadata.
      # @raise [Sinatra::NotFound] If the algorithm ID is not found.
      # @note Explicitly sets content type to 'text/turtle' as a workaround for clients requesting JSON but requiring Turtle.
      # @example
      #   # GET /champion/algorithms/u/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
      get '/champion/algorithms/*', provides: ['text/turtle', :html, 'application/ld+json', :json] do
        algorithmid = params[:splat].first
        algorithm = fetch_algorithm(algorithmid)
        @dcat = algorithm.gather_metadata # @dcat is an rdf::graph object

        warn 'content type', content_type
        # content_type = 'text/turtle'
        case content_type
        when %r{text/html}
          halt erb :algorithm_display, layout: :algorithm_layout
        when %r{application/json} || %r{application/ld+json}
          halt @dcat.dump(:jsonld)
        when %r{text/turtle}
          halt @dcat.dump(:turtle)
        end
        halt @dcat.dump(:turtle)
      end

      # Renders a form for initiating an algorithm assessment.
      # @return [String] The rendered ERB template for algorithm assessment initiation.
      # @example
      #   # GET /champion/assess/algorithms/new
      get '/champion/assess/algorithms/new' do
        @list = Algorithm.list
        halt erb :algorithm_initiate, layout: :algorithm_initiate_layout
      end

      # Redirects a POST request to assess an algorithm to the specific algorithm assessment endpoint.
      # @param calculation_uri [String] The Google Spreadsheet URI for the algorithm.
      # @return [void] Redirects to the algorithm assessment endpoint.
      # @raise [RuntimeError] If no calculation URI is provided.
      # @example
      #   # POST /champion/assess/algorithm
      #   # Form data: calculation_uri=https://docs.google.com/spreadsheets/d/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
      post '/champion/assess/algorithm' do
        calculation_uri = params['calculation_uri']
        abort 'no calc uri' unless calculation_uri
        algoid = calculation_uri.match(%r{/(\w/[^/]+)})[1]
        new_env = request.env.merge('PATH_INFO' => "/champion/assess/algorithm/#{algoid}")
        call(new_env)
      end

      # Returns the OpenAPI specification for an algorithm assessment endpoint.
      # @param algorithmid [String] The identifier of the algorithm.
      # @return [String] The OpenAPI specification in JSON format.
      # @example
      #   # GET /champion/assess/algorithm/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
      get '/champion/assess/algorithm/*', provides: [:json] do
        algorithmid = params[:splat].first
        content_type :json
        openapi_spec = Algorithm.generate_assess_algorithm_openapi(algorithmid: algorithmid)
        halt openapi_spec.to_json
      end

      # Redirects trailing slash requests for algorithm assessment to the canonical endpoint.
      # @param algorithmid [String] The identifier of the algorithm.
      # @return [void] Redirects to '/champion/assess/algorithm/:algorithmid' with a 301 status.
      # @example
      #   # GET /champion/assess/algorithm/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w/
      get '/champion/assess/algorithm/*/' do
        algorithmid = params[:splat].first
        redirect "/champion/assess/algorithm/#{algorithmid}", 301
      end

      # Executes an algorithm assessment with provided GUID or result set.
      # @param algorithmid [String] The identifier of the algorithm.
      # @return [String] HTML or JSON representation of the assessment results.
      # @raise [Sinatra::NotFound] If the algorithm ID is not found.
      # @raise [Sinatra::BadRequest] If neither GUID nor result set is provided, or if JSON is invalid.
      # @example
      #   # POST /champion/assess/algorithm/16s2klErdtZck2b6i2Zp_PjrgpBBnnrBKaAvTwrnMB4w
      #   # Body: {"guid": "https://example.org/target/456"}
      post '/champion/assess/algorithm/*', provides: [:html, :json, 'application/ld+json'] do
        algorithmid = params[:splat].first

        scoringfunction = Algorithm.retrieve_by_id(algorithm_id: algorithmid)
        unless scoringfunction
          render_error(404,
                       'Need valid algorithm id (in the URL, and already registered in the OSTrails Index) is required')
        end

        guid = nil
        resultset = nil
        if request.content_type == 'application/json'
          begin
            body = JSON.parse(request.body.read)
            if body.is_a?(Hash) && (body['guid'] || body['resultset'])
              guid = body['guid']
              resultset = body['resultset']
            else
              resultset = body
            end
          rescue JSON::ParserError => e
            render_error(400, "Invalid JSON: #{e.message}")
          end
        else
          guid = params[:guid]
          resultset = params[:resultset]
          if params[:file] && !params[:file].empty? && params[:file][:tempfile]
            begin
              resultset ||= params[:file][:tempfile].read
              JSON.parse(resultset)
            rescue JSON::ParserError => e
              render_error(400, "Invalid JSON in uploaded file: #{e.message}")
            end
          end
        end

        render_error(400, 'GUID or ResultSet (or file upload) are required') unless resultset || guid

        algorithm = Algorithm.new(calculation_uri: scoringfunction, guid: guid, resultset: resultset)
        unless algorithm.valid
          render_error(406,
                       'The data provided were invalid. Check that you are using a registered algorithm')
        end
        @result = algorithm.process
        # @rdfgraph = algorithm.generate_execution_output_rdf(output: @result, algorithmid: params[:algorithmid])

        case content_type
        when %r{text/html}
          halt erb :algorithm_execution_output, layout: :algorithm_execution_layout
        when %r{application/json} || %r{application/ld+json}
          halt @result.to_json
        when %r{text/turtle}
          halt @result[:resultset]
        end
        halt 406
      end
    end

    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######
    ####    HELPERS   ######

    # Helper method to fetch and validate an algorithm by ID.
    # @param algorithm_id [String] The identifier of the algorithm.
    # @return [Algorithm] The initialized Algorithm instance.
    # @raise [Sinatra::NotFound] If the algorithm ID is not found.
    def fetch_algorithm(algorithm_id)
      calculation_uri = Algorithm.retrieve_by_id(algorithm_id: algorithm_id)
      if calculation_uri == false
        halt 406,
             erb(:error,
                 locals: { message: 'The server was unable to find that algorithm. This may be a temporary problem' })
      end
      Algorithm.new(calculation_uri: calculation_uri, guid: 'http://example.org/mock')
    end

    # Helper method to render error responses with a consistent template.
    # @param status [Integer] The HTTP status code (e.g., 400, 404).
    # @param message [String] The error message to display.
    # @return [String] The rendered ERB error template.
    def render_error(status, message)
      halt status, erb(:error, locals: { message: message })
    end
  end
end
