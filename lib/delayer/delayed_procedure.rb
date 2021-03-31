# frozen_string_literal: true

module Delayer
  class DelayedProcedure
    include Comparable

    attr_reader :state, :delayer, :reserve_at
    def initialize(delayer, delay:, &proc)
      @delayer = delayer
      @proc = proc
      case delay
      when Time
        @reserve_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay.to_f - Time.now.to_f
      else
        @reserve_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay.to_f
      end
      @cancel = false
      @procedure = nil
      @delayer.class.reserve(self)
    end

    def register
      if !canceled?
        @procedure = Procedure.new(@delayer, &@proc)
      end
      self
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
      @procedure&.cancel
      @cancel = true
      self
    end

    # Return true if canceled this task
    # ==== Return
    # true if canceled this task
    def canceled?
      procedure = @procedure
      if procedure
        procedure.canceled?
      else
        @cancel
      end
    end
  end
end
