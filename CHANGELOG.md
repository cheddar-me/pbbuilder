# Pbbuilder Changelog

A templating language, for protobuf, for Rails, inspired and influenced by [Jbuilder](https://github.com/rails/jbuilder)

Note: This library uses semantic versioning.

## Unreleased

Added:

- Caching like Rails' ActionView does.

Caching can be utilized with `pb.cache!`, giving it a block that will be executed with a cache miss:

```ruby
pb.cache! @person, expires_in: 10.minutes do
  pb.name @person.name
  pb.high_score @person.expensive_high_score_calculation
end
```

But caching can also be utilized on nested messages, setting the keyword argument `cached: true`

```ruby
# Nested messages can also be cached
pb.cache! @person do
  pb.name @person.name
  pb.best_friend partial: "racers/racer", racer: @racer.best_friend, cached: true
end
```

Changed:

- Ruby upgrade: From 3.1.0 to 3.1.2 for the lib itself. The Rubies in test matrix are upgraded to their latest point
  releases; 2.7.6, 3.0.4, and 3.1.2 respectively.
- Library upgrade: All gems are updated to the latest possible version. Most notable upgrades:
  - `rails` from version 6.1.4.4 to 6.1.7, and from version 7.0.1 to 7.0.4
  - `google-protobuf` from version 3.19.2 to 3.21.7 (for both rails versions)
  - `bundler` from version 2.3.4 to 2.3.22

## 1.12.0 Prior to 2022-10-14

A templating language, for protobuf, for Rails, inspired and influenced by [Jbuilder](https://github.com/rails/jbuilder)