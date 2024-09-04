# frozen_string_literal: true

require "pbbuilder/pbbuilder"

class Pbbuilder
  class MergeError < ::StandardError
    def self.build(current_value, updates)
      message = "Can't merge #{updates.inspect} into #{current_value.inspect}"
      self.new(message)
    end
  end
end
