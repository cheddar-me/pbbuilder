# Pbbuilder Changelog
All notable changes to this project will be documented in this file.

This format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.13.0 2023.01.18
### Added
- #merge! method added for PbbuilderTemplate class
- ActiveSupport added as a dependency for gem
- Fragment Caching support added, with #cache! and #cache_if! method in PbbuilderTemplate class.


### Changed
- Appraisal is properly configured to run against all rubies and rails combinations.
- Supported ruby version's are 2.7, 3.0, 3.1
- Superclass for pbbuilder is now active_support/proxy_object, with a fallback to active_support/basic_object.
- Library upgrade: All gems are updated to the latest possible version. Most notable upgrades:
  - `rails` from version 6.1.4.4 to 6.1.7, and from version 7.0.1 to 7.0.4
  - `google-protobuf` is let loose
  - `bundler` from version 2.3.4 to 2.3.22

### Removed
- TestUnit dependency


## 0.12.0 Prior to 2022-10-14

A templating language, for protobuf, for Rails, inspired by [Jbuilder](https://github.com/rails/jbuilder)
