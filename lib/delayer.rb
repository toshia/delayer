# -*- coding: utf-8 -*-
require "delayer/version"
require "delayer/error"
require "delayer/extend"
require "delayer/procedure"
require "delayer/delayed_procedure"
require "monitor"

module Delayer
  class << self
    attr_accessor :default

    # Generate new Delayer class.
    # ==== Args
    # [options]
    #   Hash
    #   expire :: processing expire (secs, 0=unlimited)
    #   priority :: priorities
    #   default :: default priotity
    # ==== Return
    # A new class
    def generate_class(options = {})
      Class.new do
        include ::Delayer
        @expire = options[:expire] || 0
        if options.has_key?(:priority)
          @priorities = options[:priority].to_a.freeze
          @default_priority = options[:default]
        else
          @priorities = [:normal]
          @default_priority = :normal
        end
      end
    end

    def method_missing(fn, *args, **kwrest, &proc)
      if kwrest.empty?
        (@default ||= generate_class).__send__(fn, *args, &proc)
      else
        (@default ||= generate_class).__send__(fn, *args, **kwrest, &proc)
      end
    end
  end
end
