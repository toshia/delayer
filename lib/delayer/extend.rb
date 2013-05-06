# -*- coding: utf-8 -*-

module Delayer
  module Extend
    attr_accessor :expire

    # Run registered jobs.
    # ==== Args
    # [current_expire] expire for processing (secs, 0=unexpired)
    # ==== Return
    # self
    def run(current_expire = @expire)
      if 0 == current_expire
        run_once while not empty?
      else
        end_time = Time.new.to_f + @expire
        run_once while not(empty?) and end_time >= Time.new.to_f
      end
    end

    # Run a job and forward pointer.
    # ==== Return
    # self
    def run_once
      @busy = true
      if @first_pointer
        @lock.synchronize {
          prev_pointer = @first_pointer
          @first_pointer = @first_pointer.next
          @last_pointer = nil unless @first_pointer
          prev_pointer
        }.run
      end
    ensure
      @busy = false
    end

    # Return if some jobs processing now.
    # ==== Args
    # [args] 
    # ==== Return
    # true if Delayer processing job
    def busy?
      @busy
    end

    # Return true if no jobs has.
    # ==== Return
    # true if no jobs has.
    def empty?
      !@first_pointer
    end

    # Return remain jobs quantity.
    # ==== Return
    # Count of remain jobs
    def size(node = @first_pointer)
      if node
        1 + size(node.next)
      else
        0
      end
    end

    # register new job.
    # ==== Args
    # [procedure] job(Delayer::Procedure)
    # ==== Return
    # self
    def register(procedure)
      @lock.synchronize do
        if @last_pointer
          @last_pointer.next = procedure
        else
          @first_pointer = procedure
        end
        @last_pointer = procedure
      end
      self
    end

    def self.extended(klass)
      klass.class_eval do
        @first_pointer = @last_pointer = nil
        @busy = false
        @expire = 0
        @lock = Mutex.new
      end
    end
  end
end
