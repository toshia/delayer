# -*- coding: utf-8 -*-

module Delayer
  class Procedure
    attr_reader :state, :delayer
    attr_accessor :next
    def initialize(delayer, &proc)
      @delayer, @proc = delayer, proc
      @state = :stop
      @next = nil
      @delayer.class.register(self)
    end

    def run
      raise Delayer::Error, "call twice Delayer::Procedure" unless :stop == @state
      @state = :run
      @proc.call
      @state = :done
      @proc = nil
    end

    # insert node between self and self.next
    # ==== Args
    # [node] insertion
    # ==== Return
    # node
    def break(node)
      tail = @next
      @next = node
      node.next = tail
      node
    end
  end
end
