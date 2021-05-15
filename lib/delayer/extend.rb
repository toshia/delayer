# frozen_string_literal: true

require 'set'

module Delayer
  attr_reader :priority

  class Bucket
    attr_accessor :first, :last, :priority_of, :stashed

    def initialize(first, last, priority_of, stashed)
      @first = first
      @last = last
      @priority_of = priority_of
      @stashed = stashed
    end

    def stash_size
      s = stashed
      if s
        1 + s.stash_size
      else
        0
      end
    end
  end

  def self.included(klass)
    klass.class_eval do
      extend Extend
    end
  end

  def initialize(priority = self.class.instance_eval { @default_priority }, *_args, delay: 0, &proc)
    self.class.validate_priority priority
    @priority = priority
    if delay == 0
      @procedure = Procedure.new(self, &proc)
    else
      @procedure = DelayedProcedure.new(self, delay: delay, &proc)
    end
  end

  # Cancel this job
  # ==== Exception
  # Delayer::AlreadyExecutedError :: if already called run()
  # ==== Return
  # self
  def cancel
    @procedure.cancel
    self
  end

  module Extend
    attr_accessor :expire
    attr_reader :exception

    def self.extended(klass)
      klass.class_eval do
        @busy = false
        @expire = 0
        @remain_hook = nil
        @exception = nil
        @remain_received = false
        @lock = Monitor.new
        @bucket = Bucket.new(nil, nil, {}, nil)
        @last_reserve = nil
        @reserves = Set.new
      end
    end

    def pop_reserve(start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC))
      if @last_reserve&.reserve_at&.<=(start_time)
        lock.synchronize do
          while @last_reserve&.reserve_at&.<=(start_time)
            @last_reserve.register
            @last_reserve = @reserves.min
            @reserves.delete(@last_reserve)
          end
        end
      end
    end

    # Run registered jobs.
    # ==== Args
    # [current_expire] expire for processing (secs, 0=unexpired)
    # ==== Return
    # self
    def run(current_expire = @expire)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
      pop_reserve(start_time)
      if current_expire == 0
        run_once_without_pop_reserve until empty?
      else
        @end_time = end_time = start_time + @expire
        run_once_without_pop_reserve while !empty? && (end_time >= Process.clock_gettime(Process::CLOCK_MONOTONIC))
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
      !!@end_time&.<(Time.new.to_f)
    end

    # Run a job and forward pointer.
    # ==== Return
    # self
    def run_once
      pop_reserve
      run_once_without_pop_reserve
    end

    private def run_once_without_pop_reserve
      if @bucket.first
        @busy = true
        procedure = forward
        procedure = forward while @bucket.first && procedure&.canceled?
        if procedure && !procedure.canceled?
          procedure.run
        end
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
      !@bucket.first
    end

    # Return remain jobs quantity.
    # ==== Return
    # Count of remain jobs
    def size(node = @bucket.first)
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
      priority = procedure.delayer.priority
      lock.synchronize do
        last_pointer = get_prev_point(priority)
        if last_pointer
          @bucket.priority_of[priority] = last_pointer.break procedure
        else
          procedure.next = @bucket.first
          @bucket.priority_of[priority] = @bucket.first = procedure
        end
        @bucket.last = @bucket.priority_of[priority] if @bucket.last
        if @remain_hook && !@remain_received
          @remain_received = true
          @remain_hook.call
        end
      end
      self
    end

    # Register reserved job.
    # It does not execute immediately.
    # it calls register() in _procedure.reserve_at_.
    # ==== Args
    # [procedure] job(Delayer::DelayedProcedure)
    # ==== Return
    # self
    def reserve(procedure)
      lock.synchronize do
        if @last_reserve
          if @last_reserve > procedure
            @reserves.add(@last_reserve)
            @last_reserve = procedure
          else
            @reserves.add(procedure)
          end
        else
          @last_reserve = procedure
        end
      end
      self
    end

    def register_remain_hook(&proc)
      @remain_hook = proc
    end

    def get_prev_point(priority)
      if @bucket.priority_of[priority]
        @bucket.priority_of[priority]
      else
        @priorities.index(priority)&.yield_self do |index|
          next_index = index - 1
          get_prev_point @priorities[next_index] if next_index >= 0
        end
      end
    end

    def validate_priority(symbol)
      unless @priorities.include? symbol
        raise Delayer::InvalidPriorityError, "undefined priority '#{symbol}'"
      end
    end

    # DelayerのStashレベルをインクリメントする。
    # このメソッドが呼ばれたら、その時存在するジョブは退避され、stash_exit!が呼ばれるまで実行されない。
    def stash_enter!
      @bucket = Bucket.new(nil, nil, {}, @bucket)
      self
    end

    # DelayerのStashレベルをデクリメントする。
    # このメソッドを呼ぶ前に、現在のレベルに存在するすべてのジョブを実行し、Delayer#empty?がtrueを返すような状態になっている必要がある。
    # ==== Raises
    # [Delayer::NoLowerLevelError] stash_enter!が呼ばれていない時
    # [Delayer::RemainJobsError] ジョブが残っているのにこのメソッドを呼んだ時
    def stash_exit!
      stashed = @bucket.stashed
      raise Delayer::NoLowerLevelError, 'stash_exit! called in level 0.' unless stashed
      raise Delayer::RemainJobsError, 'Current level has remain jobs. It must be empty current level jobs in call this method.' unless empty?

      @bucket = stashed
    end

    # 現在のDelayer Stashレベルを返す。
    def stash_level
      @bucket.stash_size
    end

    private

    def forward
      lock.synchronize do
        prev = @bucket.first
        raise 'Current bucket not found' unless prev
        nex = @bucket.first = prev.next
        @bucket.last = nil unless nex
        @bucket.priority_of.each do |priority, pointer|
          @bucket.priority_of[priority] = nex if prev == pointer
        end
        prev.next = nil
        prev
      end
    end

    def lock
      @lock
    end
  end
end
