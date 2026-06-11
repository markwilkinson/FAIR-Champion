# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
