# frozen_string_literal: true

require "pbbuilder/errors"
require "pbbuilder/protobuf_extension"
require "pbbuilder/railtie" if defined?(Rails)

# Pbbuilder makes it easy to create a protobuf message using the builder pattern.
# It is heavily inspired by jbuilder
#
# Given this example message definition:
# message Person {
#   string name = 1;
#   repeated Person friends = 2;
# }
#
# You can use Pbbuilder as follows:
#
# person = RPC::Person.new
#
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

class Pbbuilder < BasicObject
  def initialize(message)
    @message = message

    yield self if ::Kernel.block_given?
  end

  def method_missing(...)
    set!(...)
  end

  def attributes!
    @message.to_h
  end

  def respond_to_missing?(field)
    !!_descriptor_for_field(field)
  end

  # When calling for ex: response.drivers, where response is a Google::Protobuf object, 'drivers' is not a method on that. These
  # methods (or messages in our case) get added here. This is of course based on what kind of message it is. Singular, an array
  # (repeated) etc. with their arguments.
  def set!(field, *args, &block)
    name = field.to_s
    descriptor = _descriptor_for_field(name)
    ::Kernel.raise ::ArgumentError, "Unknown field: #{name}" if descriptor.nil?

    # An block is used to pass on it's children
    if ::Kernel.block_given?
      ::Kernel.raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

      if descriptor.label == :repeated
        # example syntax that should end up here:
        #    pb.field @array { |element| pb.name element.name }
        ::Kernel.raise ::ArgumentError, "wrong number of arguments #{args.length} (expected 1)" unless args.length == 1
        collection = args.first
        _append_repeated(name, descriptor, collection, &block)
      else
        # example syntax that should end up here:
        #   pb.field { pb.name "hello" }
        ::Kernel.raise ::ArgumentError, "wrong number of arguments (expected 0)" unless args.empty?

        message = (@message[name] ||= _new_message_from_descriptor(descriptor))
        _scope(message, &block)
      end
    # No block given, but with 1 argument
    elsif args.length == 1
      arg = args.first
      if descriptor.label == :repeated
        if arg.respond_to?(:to_hash)
          # example syntax that should end up here:
          #   pb.fields {"one" => "two"}

          arg.to_hash.each { |k, v| @message[name][k] = v }
        elsif arg.respond_to?(:to_ary) && !descriptor.type.eql?(:message)
          # pb.fields ["one", "two"]

          @message[name].replace arg.to_ary
        elsif arg.respond_to?(:to_ary) && descriptor.type.eql?(:message)
          # pb.friends [Person.new(name: "Johnny Test"), Person.new(name: "Max Verstappen")]
          #
          # Accepts both objects that can be to_hash-translated into keyword arguments
          # for creating a nested proto message object and actual proto message objects
          # which can be assigned "as is". With "as-is" assignment the proto message can be stored
          # in memory and reused
          nested_messages = arg.map do |arg_member_message_or_hash|
            # If the arg passed already is a proto message and is the same as the
            # field expects - just use it as-is
            if arg_member_message_or_hash.is_a?(descriptor.subtype.msgclass)
              arg_member_message_or_hash
            else
              descriptor.subtype.msgclass.new(arg_member_message_or_hash)
            end
          end
          @message[name].replace(nested_messages)
        else
          # example syntax that should end up here:
          #   pb.fields "one"
          @message[name].replace [arg]
        end
      else
        # example syntax that should end up here:
        #   pb.field "value"

        @message[name] = arg
      end
    else
      # example syntax that should end up here:
      #   pb.field @value, :id, :name, :url
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

  # Shorthand command for getting a few attributes from an object.
  #     pb.extract! racer, :name, :id, :age
  def extract!(element, *args)
    args.each { |arg| @message[arg.to_s] = element.send(arg) }
  end

  # Merges object into a protobuf message, mainly used for caching.
  #
  # @param object [Hash]
  def merge!(object)
    ::Kernel.raise Pbbuilder::MergeError.build(target!, object) unless object.class == ::Hash

    object.each do |key, value|
      next if value.respond_to?(:empty?) && value.empty?

      descriptor = _descriptor_for_field(key)
      ::Kernel.raise ::ArgumentError, "Unknown field #{key}" if descriptor.nil?

      if descriptor.label == :repeated
        # optional empty fields don't show up in @message object,
        # we recreate empty message, so we can fill it with values
        if @message[key.to_s].nil?
          @message[key.to_s] = _new_message_from_descriptor(descriptor)
        end

        if value.respond_to?(:to_hash)
          value.to_hash.each {|k, v| @message[key.to_s][k] = v}
        elsif value.respond_to?(:to_ary)
          elements = value.map do |obj|
            descriptor.subtype ? descriptor.subtype.msgclass.new(obj) : obj
          end

          @message[key.to_s].replace(elements)
        end
      else
        if descriptor.type == :message
          @message[key.to_s] = descriptor.subtype.msgclass.new(value)
        else
          # pb.fields {"one" => "two"}
          # pb.boolean true || false
          # pb.field_name do
          #    pb.tags ["ok", "cool"]
          # end

          @message[key.to_s] = value
        end
      end
    end
  end

  # @return Initialized message object
  def target!
    @message
  end

  # @param field string
  def new_message_for(field)
    descriptor = _descriptor_for_field(field)
    ::Kernel.raise ::ArgumentError, "Unknown field #{field}" if descriptor.nil?

    _new_message_from_descriptor(descriptor)
  end

  private

  # Lookup the field name (or 'attribute' name, for ex "best_friend") on the Google descriptor (Google::Protobuf::Descriptor) of our
  # message object.
  # @param field string
  def _descriptor_for_field(field)
    @message.class.descriptor.lookup(field.to_s)
  end

  # Appends protobuf objects to our 'repeated' attribute. This can create a list of items to a repeated field.
  #
  # @param name string
  # @param descriptor Google::Protobuf::FieldDescriptor
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

  # Yields a Protobuf object in the scope of message and provided values.
  # This will 'assign' the field values as it were to the message attributes.
  #
  # @param message Google::Protobuf::(field_type)
  def _scope(message)
    old_message = @message
    @message = message
    yield
    message
  ensure
    @message = old_message
  end

  # Builds up an empty protobuf message based on the given descriptor.
  #
  # @param descriptor Google::Protobuf::FieldDescriptor
  def _new_message_from_descriptor(descriptor)
    ::Kernel.raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

    # Here we're using Protobuf reflection to create an instance of the message class
    message_descriptor = descriptor.subtype
    message_class = message_descriptor.msgclass
    message_class.new
  end
end
