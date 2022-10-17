require "test_helper"
require "action_view/testing/resolvers"

class PbbuilderTemplateCachingTest < ActiveSupport::TestCase
 RACER_PARTIAL = <<-PBBUILDER
    pb.cache!(racer) do
      pb.extract! racer, :name
      pb.friends racer.friends, partial: "racers/racer", as: :racer if racer.friends.present?
      pb.best_friend partial: "racers/racer", racer: racer.best_friend if racer.best_friend.present?
    end
  PBBUILDER

  PARTIALS = {
    "racers/_racer.pb.pbbuilder" => RACER_PARTIAL,
  }

  setup do
    ActiveSupport::Notifications.subscribe do |name, start, finish, id, payload|
      puts "name: #{name}", "start: #{start}", "finish: #{finish}", "id: #{id}payload: ", "#{payload}"
    end
    Rails.cache = ::ActiveSupport::Cache::MemoryStore.new
  end

  test "Caching of templates and ActiveRecord like objects" do
    a_friend = Racer.new(1, "Asthmahound Chihuahua", [])
    best_friend = Racer.new(2, "Stimpy", [])
    racer = Racer.new(3, "Ren", [a_friend, best_friend, a_friend], best_friend)

    first_result = render('pb.partial! @racer', racer: racer)
    cached_result = render('pb.partial! @racer', racer: racer)

    assert_kind_of API::Person, first_result 
    assert_kind_of API::Person, cached_result

    assert_equal "Ren", first_result.name
    assert_equal "Ren", cached_result.name
  end

  # What follows is a verbatim copy of test/pbbuilder_template_test.rb

  private

  def render(source, assigns = {})
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
