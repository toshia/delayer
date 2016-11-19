# -*- coding: utf-8 -*-

module Delayer
  module Priority
    attr_reader :priority

    def self.included(klass)
      klass.class_eval do
        include ::Delayer
        extend Extend
      end
    end

    def initialize(priority = self.class.instance_eval{ @default_priority }, *args)
      self.class.validate_priority priority
      @priority = priority
      super(*args)
    end

    module Extend
      def self.extended(klass)
        klass.class_eval do
          @priority_pointer = {}
        end
      end

      # register new job.
      # ==== Args
      # [procedure] job(Delayer::Procedure)
      # ==== Return
      # self
      def register(procedure)
        priority = procedure.delayer.priority
        lock.synchronize do
          last_pointer = get_prev_point(priority)
          if last_pointer
            @priority_pointer[priority] = last_pointer.break procedure
          else
            procedure.next = @first_pointer
            @priority_pointer[priority] = @first_pointer = procedure
          end
          if @last_pointer
            @last_pointer = @priority_pointer[priority]
          end
          if @remain_hook and not @remain_received
            @remain_received = true
            @remain_hook.call
          end
        end
        self
      end

      def get_prev_point(priority)
        if @priority_pointer[priority]
          @priority_pointer[priority]
        else
          next_index = @priorities.index(priority) - 1
          get_prev_point @priorities[next_index] if 0 <= next_index
        end
      end

      def validate_priority(symbol)
        unless @priorities.include? symbol
          raise Delayer::InvalidPriorityError, "undefined priority '#{symbol}'"
        end
      end

      private

      def forward
        lock.synchronize do
          prev = @first_pointer
          @first_pointer = @first_pointer.next
          @last_pointer = nil unless @first_pointer
          @priority_pointer.each do |priority, pointer|
            @priority_pointer[priority] = @first_pointer if prev == pointer
          end
          prev.next = nil
          prev
        end
      end

    end
  end
end
