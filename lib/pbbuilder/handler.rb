# Basically copied and pasted from JbuilderHandler, except it uses Pbbuilder

class PbbuilderHandler
  # This builds up a Ruby string, that Rails' templating system `eval`s to create the view result.
  # In our case the view result is a Protobuf message.
  def self.call(template, source = nil)
    source ||= template.source
    # We need to keep `source` on the first line, so line numbers are correct if there's an error
    %{pb=Pbbuilder.new(response_class.new); #{source}
      pb.target!}
  end
end
