# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "rails"
require "rails/test_help"
require "rails/test_unit/reporter"
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
    end
  end
end

module API
  Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
end
