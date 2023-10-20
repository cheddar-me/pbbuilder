# frozen_string_literal: true

require 'action_view/renderer/collection_renderer'

class Pbbuilder
  class CollectionRenderer < ::ActionView::CollectionRenderer # :nodoc:
    def initialize(lookup_context, options, &scope)
      super(lookup_context, options)
      @scope = scope
    end

    private

    def build_rendered_template(content, template, layout = nil)
      super(content || pb.attributes!, template)
    end

    def build_rendered_collection(templates, _spacer)
      pb.set!(field, templates.map(&:body))
    end

    def pb
      @options[:locals].fetch(:pb)
    end

    def field
      @options[:locals].fetch(:field).to_s
    end
  end
end
