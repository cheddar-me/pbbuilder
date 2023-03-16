# frozen_string_literal: true

require "test_helper"

class ProtobufExtensionTest < ActiveSupport::TestCase
  test ".build" do
    person = API::Person.build(name: "Hello world!") do |pb|
      pb.best_friend do
        pb.name "Johnny"
      end
    end
    assert_equal "Hello world!", person.name
    assert_equal "Johnny", person.best_friend.name
  end

  test ".build without block" do
    person = API::Person.build
    assert_equal "", person.name
  end
end
