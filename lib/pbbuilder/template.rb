# frozen_string_literal: true

require 'pbbuilder/collection_renderer'

# PbbuilderTemplate is an extension of Pbbuilder to be used as a Rails template
# It adds support for partials.
class PbbuilderTemplate < Pbbuilder
  class << self
    attr_accessor :template_lookup_options
  end

  self.template_lookup_options = {handlers: [:pbbuilder]}

  def initialize(context, message)
    @context = context
    super(message)
  end

  # Render a partial. Can be called as:
  #
  # pb.partial! "name/of_partial", argument: 123
  # pb.partial! "name/of_partial", locals: {argument: 123}
  # pb.partial! partial: "name/of_partial", argument: 123
  # pb.partial! partial: "name/of_partial", locals: {argument: 123}
  # pb.partial! @model # @model is an ActiveModel value, it will use the name to look up a partial
  def partial!(*args)
    if args.one? && _is_active_model?(args.first)
      _render_active_model_partial args.first
    else
      _render_explicit_partial(*args)
    end
  end

  # Sets the value in the message field.
  #
  # @example
  #  pb.friends @friends, partial: "friend", as: :friend
  #  pb.friends partial: "racers/racer", as: :racer, collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]
  #  pb.best_friend partial: "person", person: @best_friend
  #  pb.friends "racers/racer", as: :racer, collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]

  def set!(field, *args, **kwargs, &block)
    # If any partial options are being passed, we render a submessage with a partial
    if kwargs.has_key?(:partial)
      if args.one? && kwargs.has_key?(:as)
        # Example syntax that should end up here:
        #   pb.friends @friends, partial: "friend", as: :friend
        # Call set! on the super class, passing in a block that renders a partial for every element
        super(field, *args) do |element|
          _set_inline_partial(element, kwargs)
        end
      elsif kwargs.has_key?(:collection) && kwargs.has_key?(:as)
        # Example syntax that should end up here:
        #   pb.friends partial: "racers/racer", as: :racer, collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]

        _render_collection_with_options(field, kwargs[:collection], kwargs)
      else
        # Example syntax that should end up here:
        # pb.best_friend partial: "person", person: @best_friend
        super(field, *args) do
          _render_partial_with_options(kwargs)
        end
      end
    else
      if args.one? && kwargs.has_key?(:collection) && kwargs.has_key?(:as)
        # Example syntax that should end up here:
        #   pb.friends "racers/racer", as: :racer, collection: [Racer.new(1, "Johnny Test", []), Racer.new(2, "Max Verstappen", [])]
        _render_collection_with_options(field, kwargs[:collection], kwargs.merge(partial: args.first))
      else
        super
      end
    end
  end

  # Caches a fragment of a message with a given cache key. Can be called like the following:
  # 'pb.cache! "cache-key" do; end'
  # 'pb.cache! "cache-key", expire_in: 1.min do; end'
  #
  # @param key String
  # @param options Hash
  #
  # @return nil
  def cache!(key=nil, options={})
    if @context.controller.perform_caching
      value = _cache_fragment_for(key, options) do
        _scope(target!) { yield self }.to_h.compact_blank
      end

      merge! value
    else
      yield
    end
  end

  # Conditionally caches the protobuf message depending on the condition given as first parameter. Has the same
  # signature as the `cache` helper method in `ActionView::Helpers::CacheHelper` and so can be used in
  # the same way.
  #
  # Example:
  #
  #   pb.cache_if! !admin?, @person, expires_in: 10.minutes do
  #     pb.extract! @person, :name, :age
  #   end
  def cache_if!(condition, *args, &block)
    condition ? cache!(*args, &block) : yield
  end

  private

  # Uses ActionView::CollectionRenderer to render the collection effectively and to use rails' built-in fragment caching support.
  #
  # The way recursive rendering works is that the CollectionRenderer needs to be aware of the node it's currently rendering and it's parent node.
  # There is no need to know the entire "stack" of nodes. ActionView::CollectionRenderer will traverse to the bottom node, render it first and then go one level up in the stack.
  # Rince and repeat until the entire stack is rendered.

  # CollectionRenderer uses locals[:pb] to render the partial as a protobuf message,
  # but also needs locals[:pb_parent] to apply the rendered partial to the top level protobuf message.

  # This logic can be found in the CollectionRenderer#build_rendered_collection method that we overwrote.
  def _render_collection_with_options(field, collection, options)
    partial = options[:partial]

    options.reverse_merge! locals: options.except(:partial, :as, :collection, :cached)
    options.reverse_merge! ::PbbuilderTemplate.template_lookup_options

    options[:locals].merge!(pb: ::PbbuilderTemplate.new(@context, new_message_for(field)))
    options[:locals].merge!(pb_parent: self)
    options[:locals].merge!(field: field)

    if options.has_key?(:layout)
      ::Kernel.raise ::NotImplementedError, "The `:layout' option is not supported in collection rendering."
    end

    if options.has_key?(:spacer_template)
      ::Kernel.raise ::NotImplementedError, "The `:spacer_template' option is not supported in collection rendering."
    end

    CollectionRenderer
      .new(@context.lookup_context, options) { |&block| _scope(message[field.to_s], &block) }
      .render_collection_with_partial(collection, partial, @context, nil)
  end

  # Writes to cache, if cache with keys is missing.
  #
  # @return fragment value
  def _cache_fragment_for(key, options, &block)
    key = _cache_key(key, options)
    _read_fragment_cache(key, options) || _write_fragment_cache(key, options, &block)
  end

  # Reads from cache
  #
  # @param key string
  # @params options hash
  #
  # @return string
  def _read_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :read_fragment, key do
      ::Rails.cache.read(key, options)
    end
  end

  # Writes into cache and returns value
  #
  # @param key string
  # @params options hash
  #
  # @return string contents of a cache
  def _write_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :write_fragment, key do
      yield.tap do |value|
        begin
          ::Rails.cache.write(key, value, options)
        rescue ::SystemCallError
          # In case ActiveSupport::Cache::FileStore in Rails is used as a cache,
          # File.atomic_write can have a race condition and fail to rename temporary
          # file. We're attempting to recover from that, by catching this specific
          # error and returning a value.
          #
          # @see https://github.com/rails/rails/pull/44151
          # @see https://github.com/rails/rails/blob/main/activesupport/lib/active_support/core_ext/file/atomic.rb#L50
          value
        end
      end
    end
  end

  # Composes full cache key for internal storage
  #
  # @param key string
  # @param options hash
  #
  # @return string
  def _cache_key(key, options)
    name_options = options.slice(:skip_digest, :virtual_path)
    key = _fragment_name_with_digest(key, name_options)

    if @context.respond_to?(:combined_fragment_cache_key)
      key = @context.combined_fragment_cache_key(key)
    else
      key = url_for(key).split('://', 2).last if ::Hash === key
    end

    ::ActiveSupport::Cache.expand_cache_key(key, :ppbuilder)
  end

  def _fragment_name_with_digest(key, options)
    if @context.respond_to?(:cache_fragment_name)
      @context.cache_fragment_name(key, **options)
    else
      key
    end
  end

  def _is_active_model?(object)
    object.class.respond_to?(:model_name) && object.respond_to?(:to_partial_path)
  end

  def _render_explicit_partial(name_or_options, locals = {})
    case name_or_options
    when ::Hash
      # partial! partial: 'name', foo: 'bar'
      options = name_or_options
    else
      # partial! 'name', locals: {foo: 'bar'}
      options = if locals.one? && (locals.keys.first == :locals)
        locals.merge(partial: name_or_options)
      else
        {partial: name_or_options, locals: locals}
      end
      # partial! 'name', foo: 'bar'
      as = locals.delete(:as)
      options[:as] = as if as.present?
      options[:collection] = locals[:collection] if locals.key?(:collection)
    end

    _render_partial_with_options options
  end

  def _render_active_model_partial(object)
    @context.render object, pb: self
  end

  def _set_inline_partial(object, options)
    locals = ::Hash[options[:as], object]
    _render_partial_with_options options.merge(locals: locals)
  end

  def _render_partial_with_options(options)
    options.reverse_merge! locals: options.except(:partial, :as, :collection)
    options.reverse_merge! ::PbbuilderTemplate.template_lookup_options

    _render_partial options
  end

  def _render_partial(options)
    options[:locals][:pb] = self
    @context.render options
  end
end
