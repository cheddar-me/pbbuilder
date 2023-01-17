require 'pbbuilder/errors'
require 'pry'

# Pbbuilder makes it easy to create a protobuf message using the builder pattern
# It is heavily inspired by jbuilder
#
# Given this example message definition:
# message Person {
#   string name = 1;
#   repeated Person friends = 2;
# }
#
# You could use Pbbuilder as follows:
# person = RPC::Person.new
# Pbbuilder.new(person) do |pb|
#   pb.name "Hello"
#   pb.friends [1, 2, 3] do |number|
#     pb.name "Friend ##{number}"
#   end
# end
#
# message.name => "Hello"
#
# It basically works exactly like jbuilder. The main difference is that it can use introspection to figure out what kind
# of protobuf message it needs to create.

class Pbbuilder
  def initialize(message)
    @message = message

    yield self if ::Kernel.block_given?
  end

  def method_missing(...)
    set!(...)
  end

  def respond_to_missing?(field)
    !!@message.class.descriptor.lookup(field.to_s)
  end

  def set!(field, *args, &block)
    name = field.to_s
    descriptor = @message.class.descriptor.lookup(name)
    ::Kernel.raise ::ArgumentError, "Unknown field #{name}" if descriptor.nil?

    if block
      ::Kernel.raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

      if descriptor.label == :repeated
        # pb.field @array { |element| pb.name element.name }
        ::Kernel.raise ::ArgumentError, "wrong number of arguments #{args.length} (expected 1)" unless args.length == 1
        collection = args.first
        _append_repeated(name, descriptor, collection, &block)
        return
      end

      ::Kernel.raise ::ArgumentError, "wrong number of arguments (expected 0)" unless args.empty?
      # pb.field { pb.name "hello" }
      message = (@message[name] ||= _new_message_from_descriptor(descriptor))
      _scope(message, &block)
    elsif args.length == 1
      arg = args.first
      if descriptor.label == :repeated
        if arg.respond_to?(:to_hash)
          # pb.fields {"one" => "two"}
          arg.to_hash.each do |k, v|
            @message[name][k] = v
          end
        elsif arg.respond_to?(:to_ary)
          # pb.fields ["one", "two"]
          # Using concat so it behaves the same as _append_repeated
          @message[name].concat arg.to_ary
        else
          # pb.fields "one"
          @message[name].push arg
        end
      else
        # pb.field "value"
        @message[name] = arg
      end
    else
      # pb.field @value, :id, :name, :url
      element = args.shift
      if descriptor.label == :repeated
        # If the message field that's being assigned is a repeated field, then we assume that `element` is enumerable.
        # This way you can do something like pb.repeated_field @array, :id, :name
        # This will create a message out of every object in @array, copying over the :id and :name values.
        set!(name, element) do |item|
          extract!(item, *args)
        end
      else
        set!(name) do
          extract!(element, *args)
        end
      end
    end
  end

  def extract!(element, *args)
    args.each do |arg|
      value = element.send(arg)
      @message[arg.to_s] = value
    end
  end

  # Merges object into a protobuf message, mainly used for caching.
  #
  # @param object [Hash]
  def merge!(object)
    ::Kernel.raise ::MergeError.build(target!, object) unless object.class == ::Hash

    object.each_key do |key|
      #FIXME: optional empty fields don't show up in @message object,
      # we need to check that these fields are indeed defined and retrieve their type

      if object[key].empty?
        ::Kernel.raise ::MergeError.build(target!, object)
      end

      if object[key].class == String
        # pb.fields {"one" => "two"}
        @message[key.to_s] = object[key]
      elsif object[key].class == Array
        # pb.tags ['test', 'ok']
        @message[key.to_s].replace object[key]
      elsif ( obj = object[key]).class == Hash
        # pb.field_name do
        #    pb.tags ["ok", "cool"]
        # end
        #
        obj.each_key do |k|
          # pseudo-code:
          # pick descriptor from field - @message.class.descriptor
          # msg = _new_message_from_descriptor(descriptor)
          # @message[key.to_s] = _scope(msg) { block.merge!(obj[k])}
        end
      end
    end
  end

  # @return Protobuf::?? Binary body of message
  def target!
    @message
  end

  private

  # Appends protobuf message with existing @message object
  #
  # @param name string
  # @param descriptor ??
  # @param collection hash
  # @param &block
  def _append_repeated(name, descriptor, collection, &block)
    ::Kernel.raise ::ArgumentError, "expected Enumerable" unless collection.respond_to?(:map)
    elements = collection.map do |element|
      message = _new_message_from_descriptor(descriptor)
      _scope(message) { block.call(element) }
    end

    @message[name].push(*elements)
  end

  # Yields an Protobuf object in a scope of message and provided values.
  #
  # @param message Protobuf::Message::??
  def _scope(message)
    old_message = @message
    @message = message
    yield
    message
  ensure
    @message = old_message
  end

  # Build up empty protobuf message based on descriptor
  #
  # @param descriptor Protobuf::Descriptor::??
  def _new_message_from_descriptor(descriptor)
    ::Kernel.raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

    # Here we're using Protobuf reflection to create an instance of the message class
    message_descriptor = descriptor.subtype
    message_class = message_descriptor.msgclass
    message_class.new
  end
end

require "pbbuilder/protobuf_extension"
require "pbbuilder/railtie" if defined?(Rails)
