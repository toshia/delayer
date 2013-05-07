# -*- coding: utf-8 -*-
require "delayer/version"
require "delayer/error"
require "delayer/extend"
require "delayer/procedure"
require "delayer/priority"
require "monitor"

module Delayer

  def self.included(klass)
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
  def self.generate_class(options = {})
    if options[:priority]
      Class.new do
        include Priority
        @expire = options[:expire] || 0
        @priorities = options[:priority]
        @default_priority = options[:default]
      end
    else
      Class.new do
        include ::Delayer
        @expire = options[:expire] || 0
      end
    end
  end

  Default = generate_class

  def initialize(*args)
    super
    @procedure = Procedure.new(self, &Proc.new)
  end
end
