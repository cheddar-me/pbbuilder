# Pbbuilder
PBBuilder generates [Protobuf](https://developers.google.com/protocol-buffers) Messages with a simple DSL similar to the [JBuilder](https://rubygems.org/gems/jbuilder) gem.

## Requirements
This gem only supports Rails 7.0 annd Rails 7.2, **7.1 is not supported**.

There currently is a regression in ActionView (the part of Rails which renders) that forces rendered objects into strings, but for Pbbuilder we need the raw objects.
This is only present in Rails 7.1, and a fix is released in Rails 7.2. https://github.com/rails/rails/pull/51023

It might work on rails v6, but we don't guarantee that.

## Compatibility with jBuilder
We don't aim to have 100% compitability and coverage with jbuilder gem, but we closely follow jbuilder's API design to maintain familiarity.

| | Jbuilder | Pbbuilder |
|---|---|---|
| set! | ✅ | ✅ |
| cache! | ✅ | ✅ |
| cache_if! | ✅ | ✅ |
| cache_root! | ✅|  |
| fragment cache | ✅| ✅ |
| extract! | ✅ | ✅ |
| merge! | ✅ | ✅ |
| child! | ✅ |  |
| array! | ✅ |  |
| .call | ✅ |  |

Due to the protobuf message implementation, there is absolutely no need to implement support for `deep_format_keys!`, `key_format!`, `key_format`, `deep_format_keys`, `ignore_nil!`, `ignore_nil!`, `nil`. So those would never be added.

## Usage
The main difference is that it can use introspection to figure out what kind of protobuf message it needs to create.

This is an example `.proto` message.

```
message Person {
  string name = 1;
  repeated Person friends = 2;
}
```

The following `.pb` file would generate a message of valid Person type.
```
person = RPC::Person.new

Pbbuilder.new(person) do |pb|
  pb.name "Hello"
  pb.friends [1, 2, 3] do |number|
    pb.name "Friend ##{number}"
  end
end
```

Under the hood, this DSL is using `method_missing` and `set!` methods. But there are other methods and features to use.

### extract!
The following `_account.pb.pbbuilder` partial:
```
pb.id account.id
pb.phone_number account.phone_number
pb.tag account.tag
```

can be rewritten to a shorter version with the use of `extract!`.
```
pb.extract! account, :id, :phone_number, :tag
```

### Partials
Given partial `_account.pb.pbuilder`:

```
pb.name account.name
pb.registration_date account.created_at
```

Using partial while passing a variable to it

```
pb.account partial: "account", account: @account
```

Here is a way to use partials with a collection while passing a variable to it

```
pb.accounts @accounts, partial: "account", as: account
```

## Collections (or Arrays)
There are two different methods to render a collection. One that uses ActiveView::CollectionRenderer
```ruby
pb.friends partial: "racers/racer", as: :racer, collection: @racers
```

```ruby
pb.friends "racers/racer", as: :racer, collection: @racers
```

And there are other ways, that don't use CollectionRenderer
```ruby
pb.partial! @racer, racer: Racer.new(123, "Chris Harris", friends)
```
```ruby
pb.friends @friends, partial: "racers/racer", as: :racer
```

### Caching
It uses Rails.cache and works like caching in HTML templates:

```
pb.cache! "cache-key", expires_in: 10.minutes do
  pb.name @person.name
end
```

You can also conditionally cache a block by using cache_if! like this:

```
pb.cache_if! !admin?, "cache-key", expires_in: 10.minutes do
  pb.name @person.name
end
```

Fragment caching currently works through ActionView::CollectionRenderer and can only be used with the following syntax:

```ruby
pb.friends partial: "racers/racer", as: :racer, collection: @racers, cached: true
```

```ruby
pb.friends "racers/racer", as: :racer, collection: @racers, cached: true
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'pbbuilder'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install pbbuilder
```
## Development

When debugging, make sure to prepend `::Kernel` to any calls such as `puts` as otherwise the code will think you're trying to add another attribute into protobuf object.

In case you're looking to use breakpoints (for debugging purposes via `binding.pry` for instance), let Pbbuilder inherit from `Object` instead of `BasicObject`]
Seen in:
[Pbbuilder](lib/pbbuilder/pbbuilder.rb)
[Errors](lib/pbbuilder/errors.rb)

## Testing
Running `bundle exec appraisal rake test` locally will run the entire testsuit with all versions of rails.
To run tests only for a certain rails version do the following `bundle exec appraisal rails-7-0 rake test`

To run only one tests from file - use `m` utility. Like this:
`bundle exec appraisal rails-7-0 m test/pbbuilder_template_test.rb:182`

## Contributing
Everyone is welcome to contribute.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
