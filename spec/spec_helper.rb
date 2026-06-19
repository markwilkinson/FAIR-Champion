# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  track_files '{app,lib}/**/*.rb'
  minimum_coverage line: 100
end

ENV['RACK_ENV'] = 'test'
require 'rspec'
require 'rack/test'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
require_relative '../app/controllers/configuration'
require_relative '../app/controllers/application_controller'
require_relative '../lib/algorithm'
require_relative '../lib/champion_core'
require_relative '../app/controllers/routes'

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/support/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true
  end

  config.around do |example|
    if example.metadata[:show_output]
      example.run
    else
      original_stdout = $stdout
      original_stderr = $stderr
      begin
        $stdout = StringIO.new
        $stderr = StringIO.new
        example.run
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
end
