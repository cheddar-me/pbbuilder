require 'bundler/inline'

gemfile(true) do
    source 'https://rubygems.org'

    gem 'activesupport', '~> 7.0.4'
    gem 'actionview', '~> 7.0.4'
    gem 'activemodel', '~> 7.0.4'
    gem 'actionpack', '~> 7.0.4'
    gem 'google-protobuf'
    gem 'pbbuilder', path: '../'
end

require 'benchmark'

require 'active_support'
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_view/test_case'
require 'google/protobuf'
require 'pbbuilder'
require 'active_model'
require 'action_controller'
require_relative '../lib/pbbuilder/handler'

Google::Protobuf::DescriptorPool.generated_pool.build do
    add_file("pbbuilder.proto", syntax: :proto3) do
      add_message "pbbuildertest.Person" do
        optional :name, :string, 1
        repeated :friends, :message, 2, "pbbuildertest.Person"
        optional :best_friend, :message, 3, "pbbuildertest.Person"
        repeated :nicknames, :string, 4
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

  
  class Racer < Struct.new(:id, :name, :friends, :best_friend, :logo)
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def persisted?
      false
    end
  end


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
    "racers/_racer.pb.pbbuilder" => RACER_PARTIAL,
    "_asset.pb.pbbuilder" => ASSET_PARTIAL,
  }

Mime::Type.register "application/vnd.google.protobuf", :pb, [], %w(pb)
ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler


def with_collection_render_method
  template = <<-PBBUILDER
    friends = [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]
    pb.friends partial: "racers/racer", as: :racer, collection: @friends
  PBBUILDER
  render(template)
end

def without_collection_render_method
  friends = [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]
  render("pb.partial! @racer", racer: Racer.new(123, "Chris Harris", friends))
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

n = 100
collection_size = 50000

Benchmark.bm do |x|
    x.report("with CollectionRender rendered 1 time:") do
      with_collection_render_method
    end

    x.report("without CollectionRender rendered 1 times:") do
      without_collection_render_method
    end
    
    x.report("with CollectionRender rendered #{n} times:") do
      n.times { with_collection_render_method }
    end

    x.report("without CollectionRender rendered #{n} times:") do
      n.times { without_collection_render_method }
    end

    x.report("with CollectionRender order #{collection_size} collection:") do
      template = <<-PBBUILDER
        friends = []
        #{collection_size}.times { |i| friends << Racer.new(i, "Johnny Test", []) }
        pb.friends partial: "racers/racer", as: :racer, collection: @friends
      PBBUILDER
      render(template)
    end

    x.report("without CollectionRender order #{collection_size} collection:") do
      friends = []
      collection_size.times { |i| friends << Racer.new(i, "Johnny Test #{i}", []) }
      render("pb.partial! @racer", racer: Racer.new(123, "Chris Harris", friends))
    end
end