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
      body = content || pb.attributes!
      # Reset the working message so the next iteration starts with a clean
      # sub-message and cannot inherit fields written or pushed by this one.
      # See https://github.com/cheddar-me/pbbuilder/issues/64.
      pb._reset_message(pb_parent.new_message_for(field))
      super(body, template)
    end

    def build_rendered_collection(templates, _spacer)
      pb_parent.set!(field, templates.map(&:body))
    end

    def pb
      @options[:locals].fetch(:pb)
    end

    def pb_parent
      @options[:locals].fetch(:pb_parent)
    end

    def field
      @options[:locals].fetch(:field).to_s
    end
  end
end
