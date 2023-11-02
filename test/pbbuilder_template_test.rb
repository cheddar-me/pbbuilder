# frozen_string_literal: true

require "test_helper"
require "action_view/testing/resolvers"

class PbbuilderTemplateTest < ActiveSupport::TestCase
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

  setup { Rails.cache.clear }

  test "basic template" do
    result = render('pb.name "hello"')
    assert_equal "hello", result.name
  end

  test "render collections with partial as kwarg" do
    template = <<-PBBUILDER
      more_friends = [Racer.new(4, "Johnny Brave", [], nil, API::Asset.new(url: "https://google.com/test3.svg"))]
      friends_of_racer = [Racer.new(3, "Chris Harris", more_friends, nil, API::Asset.new(url: "https://google.com/test2.svg"))]
      racers = [Racer.new(1, "Johnny Test", friends_of_racer, nil, API::Asset.new(url: "https://google.com/test1.svg")), Racer.new(2, "Max Verstappen", [])]
      pb.friends partial: "racers/racer", as: :racer, collection: racers
    PBBUILDER
    result = render(template)

    assert_equal 2, result.friends.count
    assert_nil result.logo
    assert_equal "https://google.com/test1.svg", result.friends.first.logo.url
    assert_equal "https://google.com/test2.svg", result.friends.first.friends.first.logo.url
    assert_equal "https://google.com/test3.svg", result.friends.first.friends.first.friends.first.logo.url
  end

  test "CollectionRenderer: raises an error on a render with :layout option" do
    error = assert_raises NotImplementedError do
      render('pb.friends partial: "racers/racer", as: :racer, layout: "layout", collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]')
    end

    assert_equal "The `:layout' option is not supported in collection rendering.", error.message
  end

  test "CollectionRenderer: raises an error on a render with :spacer_template option" do
    error = assert_raises NotImplementedError do
      render('pb.friends partial: "racers/racer", as: :racer, spacer_template: "template", collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]')
    end

    assert_equal "The `:spacer_template' option is not supported in collection rendering.", error.message
  end

  test "partial by name with caching" do
    template = <<-PBBUILDER
      racers = [Racer.new(1, "Johnny Test", [], nil, API::Asset.new(url: "https://google.com/test1.svg")), Racer.new(2, "Max Verstappen", [])]
      pb.friends partial: "racers/racer", as: :racer, collection: racers, cached: true
    PBBUILDER

    result = render(template)

    assert_equal 2, result.friends.count
    assert_nil result.logo
    assert_equal "https://google.com/test1.svg", result.friends.first.logo.url
  end

  test "render collections with partial as arg" do
    skip("This will be addressed in future version of a gem")
    result = render('pb.friends "racers/racer", as: :racer, collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]')

    assert_equal 2, result.friends.count
  end

  test "partial by name with top-level locals" do
    result = render('pb.partial! "partial", name: "hello"')
    assert_equal "hello", result.name
  end

  test "submessage partial" do
    other_racer = Racer.new(2, "Max Verstappen", [])
    racer = Racer.new(123, "Chris Harris", [], other_racer)
    result = render('pb.best_friend partial: "person", person: @racer.best_friend', racer: racer)
    assert_equal "Max Verstappen", result.best_friend.name
  end

  test "hash" do
    result = render('pb.favourite_foods "pizza" => "yes"')
    assert_equal({"pizza" => "yes"}, result.favourite_foods.to_h)
  end

  test "partial by name with nested locals" do
    result = render('pb.partial! "partial", locals: { name: "hello" }')
    assert_equal "hello", result.name
  end

  test "partial by options containing nested locals" do
    result = render('pb.partial! partial: "partial", locals: { name: "hello" }')
    assert_equal "hello", result.name
  end

  test "partial by options containing top-level locals" do
    result = render('pb.partial! partial: "partial", name: "hello"')
    assert_equal "hello", result.name
  end

  test "partial for Active Model" do
    result = render("pb.partial! @racer", racer: Racer.new(123, "Chris Harris", []))
    assert_equal "Chris Harris", result.name
  end

  test "collection partial" do
    friends = [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]
    result = render("pb.partial! @racer", racer: Racer.new(123, "Chris Harris", friends))
    assert_equal 2, result.friends.size
    assert_equal "Johnny Test", result.friends[0].name
    assert_equal "Max Verstappen", result.friends[1].name
  end

  test "nested message partial" do
    other_racer = Racer.new(2, "Max Verstappen", [])
    result = render("pb.partial! @racer", racer: Racer.new(123, "Chris Harris", [], other_racer))
    assert_equal "Max Verstappen", result.best_friend.name
  end

  test "support for merge! method" do
    result = render('pb.merge! "name" => "suslik"')

    assert_equal("suslik", result.name)
  end

  test "boolean support in merge! method" do
    assert(render('pb.merge! "boolean_me" => true').boolean_me)
    refute(render('pb.merge! "boolean_me" => false').boolean_me)
  end

  test "support for merge! method in a block" do
    result = render(<<-PBBUILDER)
      pb.best_friend do
        pb.merge! "name" => "Manuelo"
      end
    PBBUILDER

    assert_equal("Manuelo", result.best_friend.name)
  end

  test "should raise Error in merge! an empty hash" do
    assert_nothing_raised {
      render(<<-PBBUILDER)
        pb.merge! "name" => {}
      PBBUILDER
    }

    assert_nothing_raised {
      render(<<-PBBUILDER)
        pb.merge! "" => {}
      PBBUILDER
    }
  end

  test "caching a message object" do
    template = <<-PBBUILDER
      pb.cache! "some-random-key-again" do
        pb.best_friend do
          pb.name "Max Verstappen"
          pb.logo do
            pb.url('https://google.com/image.jpg')
            pb.url_2x('https://google.com/image.jpg')
            pb.url_3x('https://google.com/image.jpg')
          end
        end
        pb.logo do
          pb.url('https://google.com/image.jpg')
          pb.url_2x('https://google.com/image.jpg')
          pb.url_3x('https://google.com/image.jpg')
        end
      end
    PBBUILDER

    assert_nothing_raised { render(template) }

    result = render('pb.cache! "some-random-key-again" do; end ')

    assert_equal('https://google.com/image.jpg', result.logo.url)
    assert_equal('https://google.com/image.jpg', result.logo.url_2x)
    assert_equal('https://google.com/image.jpg', result.logo.url_3x)

    assert_equal('https://google.com/image.jpg', result.best_friend.logo.url)
    assert_equal('https://google.com/image.jpg', result.best_friend.logo.url_2x)
    assert_equal('https://google.com/image.jpg', result.best_friend.logo.url_3x)
  end

  test "empty fragment caching" do
    render 'pb.cache! "nothing" do; end'

    result = nil

    assert_nothing_raised do
      result = render(<<-PBBUILDER)
        pb.name "suslik"
        pb.cache! "nothing" do; end
      PBBUILDER
    end

    assert_equal "suslik", result["name"]
  end

  test "caching repeated partial" do
    template = <<-PBBUILDER
      pb.cache! "some-random-key" do
        pb.friends @friends, partial: "racers/racer", as: :racer
      end
    PBBUILDER
    friends = [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]

    result = assert_nothing_raised { render(template, friends: friends) }
    assert_equal("Johnny Test", result.friends[0].name)
    assert_equal("Max Verstappen", result.friends[1].name)

    result = render('pb.cache! "some-random-key" do; end ')
    assert_equal("Johnny Test", result.friends[0].name)
    assert_equal("Max Verstappen", result.friends[1].name)
  end

  test "caching map values" do
    template = <<-PBBUILDER
      pb.cache! "some-random-cache-key" do
        pb.favourite_foods @foods
      end
    PBBUILDER

    r = assert_nothing_raised { render( template, foods: {'pizza' => 'yes', 'borsh' => 'false'})}
    assert_equal('false', r.favourite_foods['borsh'])
    assert_equal('yes', r.favourite_foods['pizza'])

    result = render('pb.cache! "some-random-cache-key" do; end ')
    assert_equal('false', result.favourite_foods['borsh'])
    assert_equal('yes', result.favourite_foods['pizza'])
  end

  test "object fragment caching" do
    render(<<-PBBUILDER)
      pb.cache! "cache-key" do
        pb.name "Hit"
      end
    PBBUILDER

    hit = render('pb.cache! "cache-key" do; end ')
    assert_equal "Hit", hit["name"]
  end

  test "fragment caching for arrays" do
    render <<-PBBUILDER
      pb.cache! "cache-key" do
        pb.tags ["ok", "cool"]
      end
    PBBUILDER

    result = render('pb.cache! "cache-key" do; end')

    assert_equal(['ok', 'cool'], result.tags)
  end

  test "optional array fragment caching" do
    render <<-PBBUILDER
      pb.cache! "cache-key" do
        pb.field_mask do
          pb.paths ["ok", "that's", "cool"]
        end
      end
    PBBUILDER

    result = render('pb.cache! "cache-key" do; end')

    assert_equal(["ok", "that's", "cool"], result.field_mask.paths)
  end

  test "object fragment caching with expiry" do
    travel_to Time.iso8601("2018-05-12T11:29:00-04:00")

    render <<-PBBUILDER
      pb.cache! "cache-key", expires_in: 1.minute do
        pb.name "Hit"
      end
    PBBUILDER

    travel 30.seconds

    result = render(<<-PBBUILDER)
      pb.cache! "cache-key", expires_in: 1.minute do
        pb.name "Miss"
      end
    PBBUILDER

    assert_equal "Hit", result["name"]

    travel 31.seconds

    result = render(<<-PBBUILDER)
      pb.cache! "cache-key", expires_in: 1.minute do
        pb.name "Miss"
      end
    PBBUILDER

    assert_equal "Miss", result["name"]
  end

  test "conditional object fragment caching" do
    render(<<-PBBUILDER)
      pb.cache_if! true, "cache-key" do
        pb.name "Hit"
      end

      pb.cache_if! false, "cache-key" do
        pb.last_name "Hit"
      end
    PBBUILDER

    result = render(<<-PBBUILDER)
      pb.cache_if! true, "cache-key" do
        pb.name "Miss"
      end

      pb.cache_if! false, "cache-key" do
        pb.last_name "Miss"
      end
    PBBUILDER

    assert_equal "Hit", result["name"]
    assert_equal "Miss", result["last_name"]
  end

  private

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
end
