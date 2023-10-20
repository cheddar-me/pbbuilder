# frozen_string_literal: true

require "pbbuilder/pbbuilder"
require 'pbbuilder/errors'
require "pbbuilder/protobuf_extension"
require "pbbuilder/railtie" if defined?(Rails)


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

  def attributes!
    @message.to_h
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
    ::Kernel.raise Pbbuilder::MergeError.build(target!, object) unless object.class == ::Hash

    object.each_key do |key|
      next if object[key].respond_to?(:empty?) && object[key].empty?

      descriptor = @message.class.descriptor.lookup(key.to_s)
      ::Kernel.raise ::ArgumentError, "Unknown field #{name}" if descriptor.nil?

      if descriptor.label == :repeated
        # optional empty fields don't show up in @message object,
        # we recreate empty message, so we can fill it with values
        if @message[key.to_s].nil?
          @message[key.to_s] = _new_message_from_descriptor(descriptor)
        end

        if object[key].respond_to?(:to_hash)
          object[key].to_hash.each {|k, v| @message[key.to_s][k] = v}
        elsif object[key].respond_to?(:to_ary)
          elements = object[key].map do |obj|
            descriptor.subtype ? descriptor.subtype.msgclass.new(obj) : obj
          end

          @message[key.to_s].replace(elements)
        end
      else
        if object[key].class == ::String
          # pb.fields {"one" => "two"}
          @message[key.to_s] = object[key]
        elsif object[key].class == ::TrueClass || object[key].class == ::FalseClass
          # pb.boolean true || false
          @message[key.to_s] = object[key]
        elsif object[key].class == ::Array
          # pb.field_name do
          #    pb.tags ["ok", "cool"]
          # end

          @message[key.to_s] = object[key]
        elsif object[key].class == ::Hash
          if @message[key.to_s].nil?
            @message[key.to_s] = _new_message_from_descriptor(descriptor)
          end

          object[key].each do |k, v|
            if object[key][k].respond_to?(:to_hash)
              if @message[key.to_s][k.to_s].nil?
                descriptor = @message[key.to_s].class.descriptor.lookup(k.to_s)
                @message[key.to_s][k.to_s] = _new_message_from_descriptor(descriptor)
              end

              _scope(@message[key.to_s][k.to_s]) { self.merge!(object[key][k]) }
            elsif object[key][k].respond_to?(:to_ary)
              @message[key.to_s][k.to_s].replace object[key][k]
            else
              # Throws an error, if we try to merge nil object into empty value.
              next if object[key][k].nil? && @message[key.to_s][k.to_s].nil?

              @message[key.to_s][k.to_s] = object[key][k]
            end
          end
        end
      end
    end
  end

  # @return Initialized message object
  def target!
    @message
  end

  private

  # Appends protobuf message with existing @message object
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

  # Yields an Protobuf object in a scope of message and provided values.
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

  # Build up empty protobuf message based on descriptor
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