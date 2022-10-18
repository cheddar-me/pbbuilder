# Pbbuilder
A templating language, for protobuf, for Rails, inspired and influenced by [Jbuilder](https://github.com/rails/jbuilder)

## Usage

See the test suite

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
