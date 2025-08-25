# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'rspec'
require 'rack/test'
require 'webmock/rspec'
require 'vcr'
require_relative '../app/controllers/configuration'
require_relative '../app/controllers/application_controller'
require_relative '../lib/algorithm'
require_relative '../lib/champion_core'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/support/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<DATABASE_PASSWORD>') { Configuration.graphdb_pass }
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end