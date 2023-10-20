
require 'active_support/concern'
require 'action_view'
require 'pry'

begin
  require 'action_view/renderer/collection_renderer'
rescue LoadError
  require 'action_view/renderer/partial_renderer'
end

class Pbbuilder
  module CollectionRenderable # :nodoc:
    extend ActiveSupport::Concern

    class_methods do
      def supported?
        superclass.private_method_defined?(:build_rendered_template) && self.superclass.private_method_defined?(:build_rendered_collection)
      end
    end

    private

    def build_rendered_template(content, template, layout = nil)
      super(content || pb.attributes!, template)
    end

    def build_rendered_collection(templates, _spacer)
      pb.merge!(templates.map(&:body))
    end

    def pb
      @options[:locals].fetch(:pb)
    end
  end

  if defined?(::ActionView::CollectionRenderer)
    # Rails 6.1 support:
    class CollectionRenderer < ::ActionView::CollectionRenderer # :nodoc:
      include CollectionRenderable

      def initialize(lookup_context, options, &scope)
        super(lookup_context, options)
        @scope = scope
      end

      private
        def collection_with_template(view, template, layout, collection)
          super(view, template, layout, collection)
        end
    end
  else
    # Rails 6.0 support:
    class CollectionRenderer < ::ActionView::PartialRenderer # :nodoc:
      include CollectionRenderable

      def initialize(lookup_context, options, &scope)
        super(lookup_context)
        @options = options
        @scope = scope
      end

      def render_collection_with_partial(collection, partial, context, block)
        render(context, @options.merge(collection: collection, partial: partial), block)
      end

      private
        def collection_without_template(view)
          super(view)
        end

        def collection_with_template(view, template)
          super(view, template)
        end
    end
  end

  class EnumerableCompat < ::SimpleDelegator
    # Rails 6.1 requires this.
    def size(*args, &block)
      __getobj__.count(*args, &block)
    end
  end
end
