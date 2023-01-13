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
  PBBUILDER

  PARTIALS = {
    "_partial.pb.pbbuilder" => "pb.name name",
    "_person.pb.pbbuilder" => PERSON_PARTIAL,
    "racers/_racer.pb.pbbuilder" => RACER_PARTIAL,

    # Ensure we find only Pbbuilder partials from within Pbbuilder templates.
    "_person.html.erb" => "Hello world!"
  }

  test "basic template" do
    result = render('pb.name "hello"')
    assert_equal "hello", result.name
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

  test "support for merge! method in a block" do
    result = render(<<-PBBUILDER)
      pb.best_friend do
        pb.merge! "name" => "Manuelo"
      end
    PBBUILDER

    assert_equal("Manuelo", result.best_friend.name)
  end

  test "should raise Error in merge! an empty hash" do
    assert_raise(ActionView::Template::Error) {
      render(<<-PBBUILDER)
        pb.merge! "name" => {}
      PBBUILDER
    }

    assert_raise(ActionView::Template::Error) {
      render(<<-PBBUILDER)
        pb.merge! "" => {}
      PBBUILDER
    }
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

    def view.view_cache_dependencies
      []
    end

    view
  end
end
