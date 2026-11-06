# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Every setting can be overridden for a project and its subprojects with a project custom field "Google Chat <setting>"
### Changed
- The order approval is disabled by default; enable it with the setting "Order Approval?" or per project with the project custom field "Google Chat Order Approval"

## [v0.5.0] 2026-11-06
### Added
- Approve orders: issues whose subject contains "Bestellung" get an approval button which adds the note "ist freigegeben" as the current user
- Chat messages about orders which are not approved yet get a "Freigeben" button leading to the approval button in Redmine
- Setting "Ignored Fields" to leave changes of certain fields out of update messages; updates which only change ignored fields are not sent at all
- Setting "One Thread per Issue" to post all messages about an issue to a thread of its own
### Changed
- Send messages in the Google Chat `cardsV2` format; the deprecated `cards` format is no longer used
- Reply to threads via `messageReplyOption` and `thread.threadKey` instead of the deprecated `thread_key` URL parameter
- Wiki update messages only contain the "OPEN PROJECT" button
- Rename "Hangouts Chat" to "Google Chat" in the settings
- Without a thread, every message is posted on its own instead of not being sent at all; the thread "-" still disables the messages of a project
### Removed
- Setting "Google Chat Username"; it had no effect, as Google Chat takes the sender name from the webhook
### Fixed
- Links to create a project custom field on the settings page also work when Redmine runs under a sub path like `/redmine`
- Do not write the webhook `key` and `token` to the log; anybody with the log could post into the chat space
- Load the hook listener explicitly; without eager loading (e.g. in development mode) no notifications were sent
- Validate the chat URL for new issues and wiki updates as well
- Do not send empty note paragraphs, as Google Chat would not render the whole message
- Do not save the issue in the changeset hook; this also sent the changeset update twice

## [v0.4.4] 2025-08-20
### Fixed
- [#11] fixes undefined local variable or method `unloadable' in Redmine 6

## [v0.4.3] 2024-04-22
### Fixed
- Handle Chat URL detection properly and fix errors like the following (#7)
  - The previous release did not actually fix the problem for our usecases

## [v0.4.2] 2024-04-18
### Fixed
- Handle Chat URL detection properly and fix errors like the following (#7):
  - `TypeError (no implicit conversion of Issue into String` in `listener.rb:281:in escapeHTML`

## [v0.4.1] 2023-07-27
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