require "test_helper"

class PbbuilderTest < ActiveSupport::TestCase
  test "it makes it possible to create a person" do
    person = Pbbuilder.new(API::Person.new) do |pb|
      pb.name "Hello world"
      pb.friends 1..3 do |number|
        pb.name "Friend ##{number}"
      end
    end.target!
    assert_equal person.name, "Hello world"
    assert_equal person.friends.first.name, "Friend #1"
  end

  test "it can extract fields in a nice way" do
    klass = Struct.new(:name)
    friends = [klass.new("Friend 1"), klass.new("Friend 2")]
    person = Pbbuilder.new(API::Person.new) do |pb|
      pb.name "Hello world"
      pb.friends friends, :name
      pb.best_friend friends[0], :name
    end.target!

    assert_equal person.name, "Hello world"
    assert_equal person.friends.size, 2
    assert_equal person.friends.first.name, "Friend 1"
    assert_equal person.friends.last.name, "Friend 2"
    assert_equal person.best_friend.name, "Friend 1"
  end
end
