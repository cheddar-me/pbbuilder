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

  NESTED_CACHE_PARTIAL = <<-PBBUILDER
    pb.cache!(racer) do
      pb.name racer.name
      pb.best_friend partial: "racers/nested", racer: racer.best_friend, cached: true if racer.best_friend
    end
  PBBUILDER

  PARTIALS = {
    "racers/_racer.pb.pbbuilder" => RACER_PARTIAL,
    "racers/_nested.pb.pbbuilder" => NESTED_CACHE_PARTIAL
  }

  setup do
    Rails.cache = ::ActiveSupport::Cache::MemoryStore.new
    ActiveSupport::Notifications.subscribe(/^cache_/) do |name, start, finish, id, payload|
      puts "name: #{name}", "start: #{start}", "finish: #{finish}", "id: #{id}", "payload: #{payload}"
    end
  end

  test "Caching of templates and ActiveRecord like objects" do
    a_friend = Racer.new(1, "Asthmahound Chihuahua", [])
    best_friend = Racer.new(2, "Stimpy", [])
    racer = Racer.new(3, "Ren", [a_friend, best_friend, a_friend], best_friend)

    fresh_result = render("pb.partial! @racer", racer: racer)

    assert_kind_of API::Person, fresh_result
    assert_equal "Ren", fresh_result.name

    cached_result = render("pb.partial! @racer", racer: racer)
    assert_equal fresh_result, cached_result
  end

  test "Russian doll caching (of nested messages) in a partial" do
    asthmahound_chihuahua = Racer.new(1, "Asthmahound Chihuahua")
    stimpy = Racer.new(2, "Stimpy", [], asthmahound_chihuahua)
    ren = Racer.new(3, "Ren", [], stimpy)
    fresh_result = render("pb.best_friend partial: 'racers/nested', racer: @racer", racer: ren)

    # first_friend = fresh_result.best_friend
    # best_friend = fresh_result.best_friend.best_friend
    # bestest_friend = fresh_result.best_friend.best_friend.best_friend

    # assert_kind_of API::Person, first_friend
    # assert_kind_of API::Person, best_friend
    # assert_kind_of API::Person, bestest_friend

    # assert_equal "Ren", first_friend.name
    # assert_equal "Stimpy", best_friend.name
    # assert_equal "Asthmahound Chihuahua", bestest_friend.name

    binding.pry
    cached_result = render("pb.best_friend partial: 'racers/nested', racer: @racer", racer: ren)
    assert_equal fresh_result, cached_result
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
