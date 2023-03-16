# frozen_string_literal: true

require "google/protobuf/message_exts"

module Google::Protobuf::MessageExts::ClassMethods
  def build(*args, &block)
    Pbbuilder.new(new(*args), &block).target!
  end
end
