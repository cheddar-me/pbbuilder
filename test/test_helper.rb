# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "rails"
require "rails/test_help"
require "rails/test_unit/reporter"

Rails::TestUnitReporter.executable = "bin/test"

require "google/protobuf"

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("pbbuilder.proto", syntax: :proto3) do
    add_message "pbbuildertest.Person" do
      optional :name, :string, 1
      repeated :friends, :message, 2, "pbbuildertest.Person"
      optional :best_friend, :message, 3, "pbbuildertest.Person"
    end
  end
end

module API
  Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
end
