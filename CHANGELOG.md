# Changelog

All notable changes to FAIR Champion are documented here.

## [1.1.16] - 2026-08-20

### Added
- The algorithm list page (`/champion/algorithms/`) now has the same
  keyword-filter search box as the test list page: a GET form filtering
  results (case-insensitive) by title/description, matching the pattern
  already used for `/champion/tests/`.

## [1.1.15] - 2026-08-20

### Fixed
- `Algorithm.list`'s SPARQL query grouped results by seven fields
  (`?identifier ?title ?description ?endpoint ?openapi ?benchmark
  ?calculation_uri`) instead of by identifier alone. Re-registering an
  already-registered algorithm creates a second resource in the FDP Index
  for the same `dct:identifier` (a duplicate-insert issue in the external
  FDP Index service itself, outside this repo); if that second copy's
  `calculation_uri`/title/description differ from the first by so much as
  trailing whitespace, the old query's multi-field GROUP BY treated them as
  distinct groups and listed the same algorithm twice. `Algorithm.list` now
  groups by `?identifier` only, using `SAMPLE()` for the other scalar
  fields and `GROUP_CONCAT(DISTINCT ...)` for the multi-valued
  objects/domains, so duplicate underlying records collapse into one row —
  matching how the FDP Index's own UI already displays results.

## [1.1.14] - 2026-08-20

### Fixed
- The GUI's "register new algorithm" POST handler built its post-registration
  redirect by taking the `path` component of `Algorithm#algorithm_guid` —
  which lives in the `w3id.org/FAIR-Champion` namespace — and resolving it
  against the current request's host. That sent users to
  `https://tools.ostrails.eu/FAIR-Champion/algorithms/.../display`, a URL
  that doesn't exist on the app (which is actually mounted at
  `/champion/...`), instead of the intended
  `https://tools.ostrails.eu/champion/algorithms/.../display`. The redirect
  is now built directly from `algorithm.algorithm_id` against the app's own
  `/champion/algorithms/` path, matching the route it's supposed to hit.

## [1.1.13] - 2026-08-06

### Changed
- `Champion::Core#execute_on_endpoints` now caps concurrency **per destination
  host** instead of firing every test in an algorithm simultaneously. An
  algorithm's tests are grouped by the host of their endpoint URL; different
  hosts still run fully in parallel (unchanged — most tests genuinely live on
  independent servers, and there's no reason to slow that down), but tests
  sharing the same host are now run in batches of `PER_HOST_TEST_CONCURRENCY`
  (default 3, configurable via `CHAMPION_PER_HOST_TEST_CONCURRENCY`) rather
  than all at once. Several of the most-used tests happen to share the same
  backend (most OSTrails core tests live on `tests.ostrails.eu`), so an
  algorithm with 10-20 such tests was firing 10-20 simultaneous requests at
  that one host per GUID assessed — observed directly contributing to that
  server saturating under heavy automated use. Hosts with fewer tests than
  the cap see no change in behavior or timing at all.

## [1.1.12] - 2026-08-04

### Fixed
- `Champion::Core#get_test_endpoint_for_testid` raised `NoMethodError:
  undefined method '[]' for nil:NilClass` whenever the FDP index had no
  current `dcat:endpointURL` record for a referenced test (e.g. because the
  test's origin server was temporarily unreachable and the FDP-Index-Proxy
  build for it failed). Since `Algorithm#gather_metadata` calls this once
  per test an algorithm references, one missing/unindexed test crashed the
  metadata build for the *entire* algorithm with an unhandled 500 — hiding
  it from `Algorithm.list` even though the algorithm's own definition was
  fine. The lookup now returns `nil` and logs a warning instead of raising;
  `gather_metadata` continues building the algorithm's metadata with that
  test's endpoint left unresolved rather than aborting.

## [1.1.11] - 2026-07-16

### Added
- Full user documentation in the README: key concepts, a walk-through of every homepage function (browsing/executing metric tests, running benchmark quality assessments, registering algorithms and tests) with screenshot placeholders in `docs/images/`, API curl examples, deployment instructions, and configuration reference

### Fixed
- `Gemfile.lock` re-synced to gem version 1.1.11 — CI runs bundler in frozen mode (`bundler-cache: true`), which fails whenever the locked path-gem version lags behind the gemspec
- Dockerfile: `bundle install --without development test` replaced with `bundle config set --local without 'development test' && bundle install` — the lockfile pins Bundler 4.0.3, which removed the `--without` flag, so the image build failed

## [1.1.10] - 2026-07-02

### Changed
- Dockerfile no longer installs the `development, :test` gem group (`rubocop`, `rspec`, `rspec-openapi`, `pry`, `webmock`, `vcr`, `simplecov`, `rack-test`) in the production image, and no longer installs a pinned `bundler:2.3.12` that was immediately superseded by the `Gemfile.lock`-locked `4.0.3` — both were pure wasted build time since `entrypoint.sh` only runs `run.rb`

## [1.1.9] - 2026-07-02

### Added
- Software provenance in algorithm execution output: `generate_execution_output_rdf` now records `prov:generatedAtTime` on the result set and links the `TestExecutionActivity` to a `prov:SoftwareAgent` node (`prov:wasAssociatedWith`) identifying FAIR Champion via its `w3id.org/FAIR-Champion` identifier

## [1.1.8] - 2026-07-01

### Added
- Algorithm execution output now includes `tests` and `conditions` alongside `metadata`, `test_results`, `narratives`, `resultset`, `testedguid`, and `guidances`

### Changed
- API example URLs across the algorithm and test-listing views updated from `tools.ostrails.eu` to the persistent `w3id.org/FAIR-Champion` identifier
- `Algorithm#initialize` strips trailing slashes from `baseURI`, and `generate_execution_output_rdf` now builds RDF subject/activity URIs from the instance `baseURI` instead of a hardcoded host
- OpenAPI server URL template now derives the host from `baseURI` rather than a hardcoded `tools.ostrails.eu`
- `POST /champion/assess/algorithm/*` no longer advertises `application/ld+json` in `provides`, and its `text/turtle` output branch was disabled pending a decision on turtle support
- Removed stray debug `warn` calls in the algorithm assessment route and `Algorithm#process`

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
