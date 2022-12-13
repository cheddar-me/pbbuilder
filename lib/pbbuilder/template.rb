require "active_support/cache"


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

  def set!(field, *args, **kwargs, &block)
    # If partial options are being passed, we render a submessage with a partial
    if kwargs.has_key?(:partial)
      if args.one? && kwargs.has_key?(:as)
        # pb.friends @friends, partial: "friend", as: :friend
        # Call set! on the super class, passing in a block that renders a partial for every element
        super(field, *args) do |element|
          _set_inline_partial(element, kwargs)
        end
      else
        # pb.best_friend partial: "person", person: @best_friend
        # Call set! as a submessage, passing in the kwargs as partial options
        super(field, *args) do
          _render_partial_with_options(kwargs)
        end
      end
    else
      super
    end
  end

  def cache!(key=nil, options={})
    if @context.controller.perform_caching
      value = _cache_fragment_for(key, options) do
        _scope { yield self}
      end

      merge! value
    else
      yield
    end
  end

  private

  def _cache_fragment_for(key, options, &block)
    key = _cache_key(key, options)
    _read_fragment_cache(key, options) || _write_fragment_cache(key, options, &block)
  end

  
  def _read_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :read_fragment, key do
      ::Rails.cache.read(key, options)
    end
  end

  def _write_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :_write_fragment, key do
      yield.tap do |value|
        ::Rails.cache.write(key, value, options)
      end
    end
  end

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
