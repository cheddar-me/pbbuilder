# frozen_string_literal: true

Pbbuilder = Class.new(begin
    if Rails.version >= "7.1"
        BasicObject
    else
        require 'active_support/proxy_object'
        ActiveSupport::ProxyObject
    end
rescue LoadError
    require 'active_support/basic_object'
    ActiveSupport::BasicObject
end)
