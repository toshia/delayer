# -*- coding: utf-8 -*-

module Delayer
  module Extend
    attr_accessor :expire
    attr_reader :exception

    def self.extended(klass)
      klass.class_eval do
        @first_pointer = @last_pointer = nil
        @busy = false
        @expire = 0
        @remain_hook = nil
        @exception = nil
        @remain_received = false
        @lock = Mutex.new
      end
    end

    # Run registered jobs.
    # ==== Args
    # [current_expire] expire for processing (secs, 0=unexpired)
    # ==== Return
    # self
    def run(current_expire = @expire)
      if 0 == current_expire
        run_once while not empty?
      else
        @end_time = Time.new.to_f + @expire
        run_once while not(empty?) and @end_time >= Time.new.to_f
        @end_time = nil
      end
      if @remain_hook
        @remain_received = !empty?
        @remain_hook.call if @remain_received  
      end
    rescue Exception => e
      @exception = e
      raise e
    end

    def expire?
      if defined?(@end_time) and @end_time
        @end_time < Time.new.to_f
      else
        false
      end
    end

    # Run a job and forward pointer.
    # ==== Return
    # self
    def run_once
      if @first_pointer
        @busy = true
        procedure = forward
        procedure = forward while @first_pointer and procedure.canceled?
        procedure.run unless procedure.canceled?
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
      lock.synchronize do
        if @last_pointer
          @last_pointer = @last_pointer.break procedure
        else
          @last_pointer = @first_pointer = procedure
        end
        if @remain_hook and not @remain_received
          @remain_received = true
          @remain_hook.call
        end
      end
      self
    end

    def register_remain_hook
      @remain_hook = Proc.new
    end

    private

    def forward
      lock.synchronize do
        prev = @first_pointer
        @first_pointer = @first_pointer.next
        @last_pointer = nil unless @first_pointer
        prev
      end
    end

    def lock
      @lock
    end

  end
end
