# frozen_string_literal: true

require "test_helper"

class PbbuilderTest < ActiveSupport::TestCase
  test "it makes it possible to create a person" do
    person = Pbbuilder.new(API::Person.new) do |pb|
      pb.name "Hello world"
      pb.friends 1..3 do |number|
        pb.name "Friend ##{number}"
      end
      pb.best_friend do
        pb.name "Manuelo"
      end
      pb.field_mask do
        pb.paths ["ok", "that's"]
        pb.paths "cool"
      end
      pb.favourite_foods({
        "Breakfast" => "Eggs",
        "Lunch" => "Shawarma",
        "Dinner" => "Pizza"
      })
    end.target!

    assert_equal "Hello world", person.name
    assert_equal "Friend #1", person.friends.first.name
    assert_equal ["cool"], person.field_mask.paths
    assert_equal "Manuelo", person.best_friend.name
    assert_equal "Eggs", person.favourite_foods["Breakfast"]
  end

  test "replaces the repeated field's value with the last one set" do
    person = Pbbuilder.new(API::Person.new) do |pb|
      pb.field_mask do
        pb.paths ["ok", "that's"]
      end
    end.target!

    p = Pbbuilder.new(person) do |pb|
      pb.field_mask do
        pb.paths ["ok", "that's"]
      end
    end.target!

    assert_equal(["ok", "that's"], p.field_mask.paths)
  end
  
  test "sets the last value of the repeated field to be the only value" do
    person = Pbbuilder.new(API::Person.new) do |pb|
      pb.field_mask do
        pb.paths ["ok", "that's"]
        pb.paths ["cool"]
      end
    end.target!

    assert_equal ["cool"], person.field_mask.paths
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
