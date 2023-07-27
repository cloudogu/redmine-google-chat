# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Chat message does not contain changed fields and their values (#5)

## [v0.4.0] 2023-07-11
### Changed
- Rename modules to match the structure required by zeitwerk (#3)

## [v0.3.0] 2022-05-12
### Changed
- Add topic field to newly created issues
### Fixed
- Do not send empty elements; Google Chat does not render the whole message if there are elements with empty content (#1)