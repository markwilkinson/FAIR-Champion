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
