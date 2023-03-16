# frozen_string_literal: true

require "pbbuilder/template"

# Basically copied and pasted from JbuilderHandler, except it uses Pbbuilder

class PbbuilderHandler
  # This builds up a Ruby string, that Rails' templating system `eval`s to create the view result.
  # In our case the view result is a Protobuf message.
  def self.call(template, source = nil)
    source ||= template.source
    # We need to keep `source` on the first line, so line numbers are correct if there's an error
    %{__already_defined = defined?(pb); pb ||= PbbuilderTemplate.new(self, @_response_class.new); #{source}
      pb.target! unless (__already_defined && __already_defined != "method")}
  end
end
