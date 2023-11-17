# frozen_string_literal: true

require "bundler/setup"

require "rails"

require "active_support"
require "active_support/core_ext/array/access"
require "active_support/cache/memory_store"
require "active_support/json"
require "active_model"
require "action_view"

require "pbbuilder"

require "google/protobuf"
require "google/protobuf/field_mask_pb"

require "active_support/testing/autorun"
require "pry"

ActiveSupport.test_order = :random

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("pbbuilder.proto", syntax: :proto3) do
    add_message "pbbuildertest.Person" do
      optional :name, :string, 1
      repeated :friends, :message, 2, "pbbuildertest.Person"
      optional :best_friend, :message, 3, "pbbuildertest.Person"
      repeated :nicknames, :string, 4
      optional :field_mask, :message, 5, "google.protobuf.FieldMask"
      map :favourite_foods, :string, :string, 6
      repeated :tags, :string, 7
      optional :last_name, :string, 8
      optional :boolean_me, :bool, 9
      optional :logo, :message, 10, "pbbuildertest.Asset"
    end

    add_message "pbbuildertest.Asset" do
      optional :url, :string, 1
      optional :url_2x, :string, 2
      optional :url_3x, :string, 3
    end
  end
end

module API
  Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
  Asset = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Asset").msgclass
end

class << Rails
  def cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

class Racer < Struct.new(:id, :name, :friends, :best_friend, :logo)
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  # Fragment caching needs to know, if record could be persisted. We set it to false, this is a default in ActiveModel::API.
  def persisted?
    false
  end
end

Mime::Type.register "application/vnd.google.protobuf", :pb, [], %w(pb)
ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler
