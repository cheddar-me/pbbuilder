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

# Regenerate Ruby descriptors from proto if needed, and require them.
# This does require protoc to be installed
proto_file = File.expand_path("test_proto.proto", __dir__)
ruby_out = File.expand_path("test_proto_pb.rb", __dir__)
if !File.exist?(ruby_out) || File.mtime(ruby_out) < File.mtime(proto_file)
  system("protoc --proto_path=#{File.dirname(proto_file)} --ruby_out=#{File.dirname(ruby_out)} #{proto_file}")
end
require_relative "test_proto_pb"

module API
  Person = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Person").msgclass
  Asset = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("pbbuildertest.Asset").msgclass
end

class << Rails
  def cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

Pbbuilder::CollectionRenderer.collection_cache = Rails.cache

class Racer < Struct.new(:id, :name, :friends, :best_friend, :logo)
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  def cache_key
    "racer-#{id}"
  end

  # Fragment caching needs to know, if record could be persisted. We set it to false, this is a default in ActiveModel::API.
  def persisted?
    false
  end
end

Mime::Type.register "application/vnd.google.protobuf", :pb, [], %w(pb)
ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler
