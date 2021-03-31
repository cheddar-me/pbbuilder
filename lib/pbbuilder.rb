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

class Pbbuilder < BasicObject
  def initialize(message)
    @message = message

    yield self if ::Kernel.block_given?
  end

  def method_missing(field, *args, &block)
    set!(field, *args, &block)
  end

  def respond_to_missing?(field)
    !!@message.class.descriptor.lookup(field.to_s)
  end

  def set!(field, *args, &block)
    name = field.to_s
    descriptor = @message.class.descriptor.lookup(name)

    if block
      raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

      if descriptor.label == :repeated
        # pb.field @array { |element| pb.name = element.name }
        raise ::ArgumentError, "wrong number of arguments (expected 1)" unless args.length == 1
        collection = args.first
        _append_repeated(name, descriptor, collection, &block)
        return
      end

      raise ::ArgumentError, "wrong number of arguments (expected 0)" unless args.empty?
      # pb.field { pb.name = "hello" }
      message = (@message[name] ||= _new_message_from_descriptor(descriptor))
      _scope(message, &block)
    elsif args.length == 1
      @message[name] = args.first
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
        extract!(element, *args)
      end
    end
  end

  def extract!(element, *args)
    args.each do |arg|
      value = element.send(arg)
      @message[arg.to_s] = value
    end
  end

  def target!
    @message
  end

  private

  def _append_repeated(name, descriptor, collection, &block)
    raise ::ArgumentError, "expected Enumerable" unless collection.respond_to?(:map)
    elements = collection.map do |element|
      message = _new_message_from_descriptor(descriptor)
      _scope(message) { block.call(element) }
    end

    @message[name].push(*elements)
  end

  def _scope(message)
    old_message = @message
    @message = message
    yield
    message
  ensure
    @message = old_message
  end

  def _new_message_from_descriptor(descriptor)
    raise ::ArgumentError, "can't pass block to non-message field" unless descriptor.type == :message

    # Here we're using Protobuf reflection to create an instance of the message class
    message_descriptor = descriptor.subtype
    message_class = message_descriptor.msgclass
    message_class.new
  end
end

require "pbbuilder/railtie" if defined?(Rails)
