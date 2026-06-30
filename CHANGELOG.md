# Changelog

All notable changes to FAIR Champion are documented here.

## [1.1.7] - 2026-06-29

### Added
- CORS access-control headers (`Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`) on all responses to support browser-based API clients
- OPTIONS preflight handler for CORS compliance

## [1.1.6] - prior release

### Added
- Test registration re-integrated into Champion
- Per-test-result execution log to explain failures
- Keyword filter for test listing endpoint
- Multipart file upload support in test-execution proxy (`submission_mode=metadata_file`)
- `harvest_only` proxy endpoint

### Changed
- Labels and colours updated in UI
- Ruby version declaration moved to `.ruby-version` file
- Removed `eval` from test execution path
- Algorithm object naming cleaned up
- Algorithm endpoint now strips incoming whitespace and fixes GUID handling

### Fixed
- JSON format of tests list response
- Bug in algorithm evaluation not correctly dispatching to individual tests
- GUID handling in algorithm assessment
- Proper content-type negotiation for API responses

## [1.1.0] - earlier

### Added
- Champion now uses SPARQL queries rather than JSON-path to extract test data
- Algorithm interoperability demonstrated with foOPS
- Algorithm display shows link to scoring spreadsheet
- Single-reference JSON-LD context handling

### Fixed
- `wasGeneratedBy` / `generated` direction corrected in provenance output
- Algorithm munging for third-party testing tools
- Trailing-slash redirect behaviour for algorithm endpoints
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.6] - 2026-06-12

### Fixed

- Strip leading/trailing whitespace from all CSV-sourced fields in `algorithm.rb`:
  `Test GUID`, `Test Reference`, metadata `Value`, and all condition fields
  (`Condition`, `Description`, `Formula`, `Success Message`, `Fail Message`, `Guidance`).
  A trailing space on a `Test GUID` caused the test to be silently absent from the
  final `TestResultSet` because the whitespace-padded URI never matched the RDF graph.

## [1.1.5] - 2026-06-12

### Changed

- Wrap each test execution thread in a `rescue` block so an unexpected exception produces an `indeterminate` `ftr:TestResult` stub rather than silently dropping that test from the ResultSet.
- Replace the two silent-skip (`next`) paths in `add_members` with `add_error_stub`, which injects an `indeterminate` `ftr:TestResult` node into the graph so JSON-LD parse failures and missing `ftr:TestResult` nodes are visible to the user in the output rather than silently absent.

## [1.1.4] - 2026-06-12

### Changed

- Remove debug `warn` calls and `RestClient.log = 'stderr'` from `run_test`; these fired on every test invocation and flooded the Docker log, especially under parallel execution.

## [1.1.3] - 2026-06-12

### Changed

- Parallelize `execute_on_endpoints` using threads so all FAIR test HTTP requests fire concurrently instead of serially; results are collected via a `Mutex`-protected array and order is not guaranteed.

## [1.1.2] - 2026-05-28

### Fixed

- Fix `parse_single_test_response` in `algorithm.rb` to query via the mandatory `ftr:outputFromTest` predicate instead of chaining through the optional `prov:wasAssociatedWith` / `prov:wasGeneratedBy` path; this caused test result lookups to silently fail for any test framework that does not emit those optional predicates.
- Remove stale `Configuration.graphdb_pass` call from VCR `filter_sensitive_data` in `spec_helper.rb`; the method had been commented out, causing all cassette-backed tests to crash in their `before_playback`/`before_record` hooks.
- Add SPARQL POST stub to the `#gather_metadata` RSpec describe block so the test no longer attempts real network connections that WebMock blocks.
- Fix `Champion::Core#get_test_endpoint_for_testid` stub in `champion__core_spec.rb` from `:get` to `:post`; `SPARQL::Client` always sends POST requests.
- Add missing `testid:` keyword argument to `run_test` call in `champion__core_spec.rb`.
- Replace plain Hash returns in `routes_content_spec.rb` `get_tests` mocks with `Champion::Test` objects; the `_onetest.erb` template calls methods (`test.identifier`, `test.title`, etc.) that do not exist on Hash.

## [1.1.1] - 2026-05-27

### Fixed

- Sanitize HTTP response bodies from test APIs to UTF-8 before JSON parsing, replacing invalid or undefined byte sequences with the Unicode replacement character (U+FFFD). Prevents copy-pasted characters (e.g. Word smart quotes, em-dashes) from causing silent parse failures downstream.
- Wrap the resultset string in `StringIO` when loading it into an RDF graph in `process` and `extract_target_from_resultset`. Passing a bare String to `RDF::Reader.new` could be misinterpreted as a file path rather than inline content, leaving `@resultsetgraph` empty and causing all tests to report "indeterminate (result data not found)".
- Apply the same UTF-8 sanitization to the Google Spreadsheet CSV response, guarding against copy-pasted non-ASCII characters in cell values (formulae, descriptions, test GUIDs, etc.).
- Apply UTF-8 sanitization to individual test JSON-LD responses before creating the `StringIO` passed to the RDF reader in `add_members`.

## [1.1.0] - prior release

### Added

- Individual test results now include a `ftr:log` field for debugging failed or indeterminate outcomes.
- Test registration re-integrated into the Champion interface.
