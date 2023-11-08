require 'bundler/inline'

gemfile(true) do
    source 'https://rubygems.org'

    gem 'activesupport', '~> 7.0.4'
    gem 'actionview', '~> 7.0.4'
    gem 'google-protobuf'
    gem 'pbbuilder', path: '../'
end

require 'benchmark'

require 'active_support'
require 'action_view'
require 'action_view/testing/resolvers'
require 'google/protobuf'
require 'pbbuilder'

Google::Protobuf::DescriptorPool.generated_pool.build do
    add_file("pbbuilder.proto", syntax: :proto3) do
      add_message "pbbuildertest.Person" do
        optional :name, :string, 1
        repeated :friends, :message, 2, "pbbuildertest.Person"
        optional :best_friend, :message, 3, "pbbuildertest.Person"
        repeated :nicknames, :string, 4
        optional :field_mask, :message, 5, "google.protobuf.FieldMask"
        map :favourite_foods, :string, :string, 6
        repeated :tags, :string, 7
        optional :last_name, :string, 8
        optional :boolean_me, :bool, 9
        optional :logo, :message, 10, "pbbuildertest.Asset"
      end
  
      add_message "pbbuildertest.Asset" do
        optional :url, :string, 1
        optional :url_2x, :string, 2
        optional :url_3x, :string, 3
      end
    end
  end
  
  module API
    Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
    Asset = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Asset").msgclass
  end
  
  class << Rails
    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end
  end
  
  class Racer < Struct.new(:id, :name, :friends, :best_friend, :logo)
    extend ActiveModel::Naming
    include ActiveModel::Conversion
  end
  

COLLECTION_RENDERER_TEMPLATE = <<-PBBUILDER
    more_friends = [Racer.new(4, "Johnny Brave", [], nil, API::Asset.new(url: "https://google.com/test3.svg"))]
    friends_of_racer = [Racer.new(3, "Chris Harris", more_friends, nil, API::Asset.new(url: "https://google.com/test2.svg"))]
    racers = [Racer.new(1, "Johnny Test", friends_of_racer, nil, API::Asset.new(url: "https://google.com/test1.svg")), Racer.new(2, "Max Verstappen", [])]
    pb.friends partial: "racers/racer", as: :racer, collection: racers
PBBUILDER

STANDARD_TEMPLATE = <<-PBBUILDER
    more_friends = [Racer.new(4, "Johnny Brave", [], nil, API::Asset.new(url: "https://google.com/test3.svg"))]
    friends_of_racer = [Racer.new(3, "Chris Harris", more_friends, nil, API::Asset.new(url: "https://google.com/test2.svg"))]
    racers = [Racer.new(1, "Johnny Test", friends_of_racer, nil, API::Asset.new(url: "https://google.com/test1.svg")), Racer.new(2, "Max Verstappen", [])]
    pb.friends racers partial: "racers/racer", as: :racer
PBBUILDER

## Probably caching doesn't work? Instead of struct object, we need to use ActiveRecord object with sqlite.
FRAGMENT_CACHING_TEMPLATE = <<-PBBUILDER
    more_friends = [Racer.new(4, "Johnny Brave", [], nil, API::Asset.new(url: "https://google.com/test3.svg"))]
    friends_of_racer = [Racer.new(3, "Chris Harris", more_friends, nil, API::Asset.new(url: "https://google.com/test2.svg"))]
    racers = [Racer.new(1, "Johnny Test", friends_of_racer, nil, API::Asset.new(url: "https://google.com/test1.svg")), Racer.new(2, "Max Verstappen", [])]
    pb.friends partial: "racers/racer", as: :racer, collection: racers, cached: true
PBBUILDER

PERSON_PARTIAL = <<-PBBUILDER
    pb.extract! person, :name
PBBUILDER

RACER_PARTIAL = <<-PBBUILDER
    pb.extract! racer, :name
    pb.friends racer.friends, partial: "racers/racer", as: :racer
    pb.best_friend partial: "racers/racer", racer: racer.best_friend if racer.best_friend.present?
    pb.logo partial: "asset", asset: racer.logo if racer.logo.present?
PBBUILDER

ASSET_PARTIAL = <<-PBBUILDER
pb.url asset.url
pb.url_2x asset.url
pb.url_3x asset.url
PBBUILDER

PARTIALS = {
    "_partial.pb.pbbuilder" => "pb.name name",
    "_person.pb.pbbuilder" => PERSON_PARTIAL,
    "racers/_racer.pb.pbbuilder" => RACER_PARTIAL,
    "_asset.pb.pbbuilder" => ASSET_PARTIAL,

    # Ensure we find only Pbbuilder partials from within Pbbuilder templates.
    "_person.html.erb" => "Hello world!"
  }


def with_collection_render_method
    render(COLLECTION_RENDERER_TEMPLATE)
end

def without_collection_render_method
    render(STANDARD_TEMPLATE)
end

def with_fragment_caching_method
    render(FRAGMENT_CACHING_TEMPLATE)
end

def render(*args)
    render_without_parsing(*args)
end

def render_without_parsing(source, assigns = {})
    view = build_view(fixtures: PARTIALS.merge("source.pb.pbbuilder" => source), assigns: assigns)
    view.render(template: "source", handlers: [:pbbuilder], formats: [:pb])
end

def build_view(options = {})
    resolver = ActionView::FixtureResolver.new(options.fetch(:fixtures))
    lookup_context = ActionView::LookupContext.new([resolver], {}, [""])
    controller = ActionView::TestCase::TestController.new

    assigns = options.fetch(:assigns, {})
    assigns.reverse_merge! _response_class: API::Person

    view = ActionView::Base.with_empty_template_cache.new(lookup_context, assigns, controller)

    def view.view_cache_dependencies; [] end
    def view.combined_fragment_cache_key(key) [ key ] end
    def view.cache_fragment_name(key, *) key end
    def view.fragment_name_with_digest(key) key end

    view
end


Benchmark.bm do |x|
    x.report("with collection render:") { with_collection_render_method }
    x.report("without collection render:") { without_collection_render_method }
    x.report("with fragment caching:") { with_fragment_caching_method }
end