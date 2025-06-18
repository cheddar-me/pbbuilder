## Unreleased

- Remove official support for Rails 7.0 and Rails 6.x, add Appraisal config for Rails 8.x
- Bump actions/checkout from 3 to 4 (#40)
- Drop support for rails v6.* versions (#60)
- Regenerate Appraisals, drop Rails 7.0
- Allow usage of google-protobuf 4.x
- Use an actual .proto for testing
- Test with both google-protobuf 3.25 and 4.x
- Remove --verbose when running rake test

## 0.19.0
- Add support for rails 7.2, but leave out rails 7.1 support. This is because ActionView has a breaking bug in 7.1 that renders the template back as a string instead of an object, like we need for Pbbuilder https://github.com/rails/rails/pull/51023 This also removes the uses of the Rails variant of BasicObject in favor of the Ruby built-in.

## 0.18.0
- Allow literal assignment of protos to fields

## 0.17.0
- Instead of appending to repeated enum message, we're replacing it to avoid issues in case output will be rendered twice
- If one field was defined twice, only last definition will end up in output
- Fixed CI by locking 3 version or lower of google-protobuf dependency.

## 0.16.2
- Add support for partial as a first argument , e.g.`pb.friends "racers/racer", as: :racer, collection: @racers`
- Add tests to verify that fragment caching is operational

## 0.16.1
- Deal properly with recursive protobuf messages while using ActiveView::CollectionRenderer

## 0.16.0
- Added support for new collection rendering, that is backed by ActiveView::CollectionRenderer.
- Refactoring and simplification of #merge! method without a change in functionality.

## 0.15.1
- #merge! method to handle repeated unintialized message object

## 0.15.0
- #merge! method was refactored to accomodate caching for all data types (especially those that are :repeated)

## 0.14.0
- Adding `frozen_string_literal: true` to all files.

## 0.13.2
- In case ActiveSupport::Cache::FileStore in Rails is used as a cache, File.atomic_write can have a race condition and fail to rename temporary file. We're attempting to recover from that, by catching this specific error and returning a value.

## 0.13.1
- #merge! to support boolean values

## 0.13.0
- #merge! method added for PbbuilderTemplate class
- ActiveSupport added as a dependency for gem
- Fragment Caching support added, with #cache! and #cache_if! methods in PbbuilderTemplate class.
- Appraisal is properly configured to run against all rubies and rails combinations.
- Supported ruby version's are 2.7, 3.0, 3.1
- Superclass for pbbuilder is now active_support/proxy_object, with a fallback to active_support/basic_object.
- Library upgrade: All gems are updated to the latest possible version. Most notable upgrades:
  - `rails` from version 6.1.4.4 to 6.1.7, and from version 7.0.1 to 7.0.4
  - `google-protobuf` is let loose
  - `bundler` from version 2.3.4 to 2.3.22
- TestUnit dependency removed

## 0.12.0 Prior to 2022-10-14

A templating language, for protobuf, for Rails, inspired by [Jbuilder](https://github.com/rails/jbuilder)
