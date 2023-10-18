# Pbbuilder
PBBuilder generates [Protobuf](https://developers.google.com/protocol-buffers) Messages with a simple DSL similar to [JBuilder](https://rubygems.org/gems/jbuilder) gem.

## Compatibility
We don't aim to have 100% compatibility with jbuilder gem, but we closely follow jbuilder's API design. 

| | Jbuilder | Pbbuilder |
|---|---|---|
|  set! | ✅ | ✅ |
|  cache! | ✅ | ✅ |
|  cache_if! | ✅ | ✅ |
| cache_root! | ✅|  |
| extract! | ✅ | ✅ |
| merge! | ✅ | ✅ |
| deep_format_keys! | ✅ |  |
| child! | ✅ |  |
| array! | ✅ |  |
| ignore_nil! | ✅ |  |

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

could be rewritten to a shorter version with a use of `extract!`.
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

Here is way to use partials with collection while passing a variable to it

```
pb.accounts @accounts, partial: "account", as: account
```

### Caching
Fragment caching is supported, it uses Rails.cache and works like caching in HTML templates:

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

In case, you're looking to use breakpoints for debugging purposes - it's better to use `pry`. Just make sure to [change pbbuilder superclass from `ProxyObject/BasicObject` to `Object`](lib/pbbuilder/pbbuilder.rb).

## Testing
Running `bundle exec appraisal rake test` locally will run entire testsuit with all version of rails. To run tests only for certain rails version do the following `bundle exec appraisal rails-7-0 rake test` or for all with `bundle exec appraisal rake test`.

You might meed to run `bundle exec appraisal install` to retrieve all dependencies.

To run only one tests from file - use `m` utility. Like this:
`bundle exec appraisal rails-7-0 m test/pbbuilder_template_test.rb:182`

## Contributing
Everyone is welcome to contribute.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
