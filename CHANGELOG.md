# Pbbuilder Changelog
All notable changes to this project will be documented in this file.

This format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.13.0
### Changed
- Appraisal is properly configured to run against all rubies and rails combinations.
- Supported ruby version's are 2.7, 3.0, 3.1
- Ruby upgrade: From 3.1.0 to 3.1.2 for the lib itself. The Rubies in test matrix are upgraded to their latest point
  releases; 2.7.6, 3.0.4, and 3.1.2 respectively.
- Library upgrade: All gems are updated to the latest possible version. Most notable upgrades:
  - `rails` from version 6.1.4.4 to 6.1.7, and from version 7.0.1 to 7.0.4
  - `google-protobuf` from version 3.19.2 to 3.21.7 (for both rails versions)
  - `bundler` from version 2.3.4 to 2.3.22

### Removed
- TestUnit dependency

### Added
- Testing agains Rails HEAD branch


## 0.12.0 Prior to 2022-10-14

A templating language, for protobuf, for Rails, inspired by [Jbuilder](https://github.com/rails/jbuilder)
