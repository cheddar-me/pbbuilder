# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "rails"
require "rails/test_help"
require "rails/test_unit/reporter"

require "active_support"
require "active_support/core_ext/array/access"
require "active_support/cache/memory_store"
require "active_support/json"
require "active_model"
require "action_view"
require "rails/version"

require "pbbuilder"

Rails::TestUnitReporter.executable = "bin/test"

require "google/protobuf"
require "google/protobuf/field_mask_pb"

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("pbbuilder.proto", syntax: :proto3) do
    add_message "pbbuildertest.Person" do
      optional :name, :string, 1
      repeated :friends, :message, 2, "pbbuildertest.Person"
      optional :best_friend, :message, 3, "pbbuildertest.Person"
      repeated :nicknames, :string, 4
      optional :field_mask, :message, 5, "google.protobuf.FieldMask"
      map :favourite_foods, :string, :string, 6
    end
  end
end

module API
  Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
end

class Racer < Struct.new(:id, :name, :friends, :best_friend)
  extend ActiveModel::Naming
  include ActiveModel::Conversion
end

Mime::Type.register "application/vnd.google.protobuf", :pb, [], %w(pb)
ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler
