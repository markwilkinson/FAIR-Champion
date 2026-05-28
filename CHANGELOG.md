# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
