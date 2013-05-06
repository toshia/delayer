# -*- coding: utf-8 -*-
require "delayer/version"
require "delayer/error"
require "delayer/extend"
require "delayer/procedure"
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
      Class.new(Priority(options)) do
        @expire = options[:expire] || 0
      end
    else
      Class.new do
        include ::Delayer
        @expire = options[:expire] || 0
      end
    end
  end

  Default = generate_class

  def initialize
    super
    @procedure = Procedure.new(self, &Proc.new)
  end
end
