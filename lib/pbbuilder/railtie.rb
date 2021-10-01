require "pbbuilder/handler"

class Pbbuilder
  class Railtie < ::Rails::Railtie
    initializer :register_handler do
      ActiveSupport.on_load :action_view do
        ActionView::Template::Types.symbols << :pb
        ActionView::Template.register_template_handler :pbbuilder, PbbuilderHandler
      end
    end
  end
end
