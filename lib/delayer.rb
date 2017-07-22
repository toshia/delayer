# -*- coding: utf-8 -*-
require "delayer/version"
require "delayer/error"
require "delayer/extend"
require "delayer/procedure"
require "delayer/priority"
require "monitor"

module Delayer
  class << self
    attr_accessor :default

    def included(klass)
      klass.extend Extend
    end

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
        include Priority
        @expire = options[:expire] || 0
        if options.has_key?(:priority)
          @priorities = options[:priority]
          @default_priority = options[:default]
        else
          @priorities = [:normal]
          @default_priority = :normal
        end
      end
    end

    def method_missing(*args, &proc)
      (@default ||= generate_class).__send__(*args, &proc)
    end
  end
end
