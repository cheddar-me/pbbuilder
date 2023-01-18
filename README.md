# Pbbuilder
PBBuilder generates [Protobuf](https://developers.google.com/protocol-buffers) Messages with a simple DSL similar to [JBuilder](https://rubygems.org/gems/jbuilder) gem.

## Usage
It basically works exactly like jbuilder. The main difference is that it can use introspection to figure out what kind of protobuf message it needs to create.


Following Pbbuilder code
```
person = RPC::Person.new
 Pbbuilder.new(person) do |pb|
   pb.name "Hello"
   pb.friends [1, 2, 3] do |number|
     pb.name "Friend ##{number}"
   end
 end
```
Would produce this message:

```
message Person {
  string name = 1;
  repeated Person friends = 2;
}
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

## Contributing

When debugging, make sure you're prepending `::Kernel` to any calls such as `puts` as otherwise the code will think you're trying to add another attribute onto the protobuf.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
