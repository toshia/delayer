# frozen_string_literal: true

module Delayer
  class DelayedProcedure
    include Comparable

    attr_reader :state, :delayer, :reserve_at, :right

    def initialize(delayer, delay:, &proc)
      @delayer = delayer
      @proc = proc
      @reserve_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay
      @left = @right = nil
      @delayer.class.reserve(self)
    end

    def add(other)
      return self unless other
      if self >= other
        other.add(self)
      else
        @left, *children, @right = [@left, @right, other].compact.sort
        child = children.first
        if child
          if @right.right
            @right = @right.add(child)
          else
            @left = @left.add(child)
          end
        end
        self
      end
    end

    def next
      @left&.add(@right).tap do
        @left = @right = nil
        freeze
      end
    end

    def register
      Procedure.new(@delayer, &@proc)
    end

    def <=>(other)
      @reserve_at <=> other.reserve_at
    end

    # Cancel this job
    # ==== Exception
    # Delayer::TooLate :: if already called run()
    # ==== Return
    # self
    def cancel
      raise 'TODO'
      self
    end

    # Return true if canceled this task
    # ==== Return
    # true if canceled this task
    def canceled?
      raise 'TODO'
    end
  end
end
