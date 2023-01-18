require 'rails'
require "pbbuilder/handler"

class Pbbuilder
  class Railtie < ::Rails::Railtie
    initializer :register_handler do
      ActiveSupport.on_load :action_view do
        Mime::Type.register "application/vnd.google.protobuf", :pb, [], %w(pb)
        ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler
      end
    end
  end
end
