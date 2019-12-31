# frozen_string_literal: true

module Delayer
  class DelayedProcedure
    attr_reader :state, :delayer, :reserve_at
    def initialize(delayer, delay:, &proc)
      @delayer = delayer
      @proc = proc
      @reserve_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay
      @delayer.class.reserve(self)
    end

    def next
      nil
    end

    def register
      Procedure.new(@delayer, &@proc)
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
