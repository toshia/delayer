# frozen_string_literal: true

module Delayer
  class DelayedProcedure
    include Comparable

    attr_reader :state, :delayer, :reserve_at, :right

    def initialize(delayer, delay:, &proc)
      @delayer = delayer
      @proc = proc
      @reserve_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay
      @left = @right = @cancel = nil
      @size = 1
      @delayer.class.reserve(self)
    end

    def size
      @size
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
            @left = @left.add(child)
          else
            @right = @right.add(child)
          end
        end
        @size += 1
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
      if !canceled?
        @procedure = Procedure.new(@delayer, &@proc)
      end
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
      if @procedure
        @procedure.cancel
      else
        @cancel = true
      end
    end

    # Return true if canceled this task
    # ==== Return
    # true if canceled this task
    def canceled?
      if @procedure
        @procedure.canceled?
      else
        @cancel
      end
    end
  end
end
