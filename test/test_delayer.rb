# -*- coding: utf-8 -*-

require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'delayer'

class TestDelayer < Test::Unit::TestCase
  def setup
    Delayer.default = nil
  end

  def test_delayed
    delayer = Delayer.generate_class
    a = 0
    delayer.new { a = 1 }

    assert_equal(0, a)
    delayer.run
    assert_equal(1, a)
  end

  def test_default
    a = 0
    Delayer.new { a = 1 }

    assert_equal(0, a)
    Delayer.run
    assert_equal(1, a)
  end

  def test_timelimited
    delayer = Delayer.generate_class(expire: 0.01)
    a = 0
    delayer.new { sleep 0.1 }
    delayer.new { a = 1 }

    assert_equal(0, a)
    delayer.run
    assert_equal(0, a)
    delayer.run
    assert_equal(1, a)
  end

  def test_busy
    delayer = Delayer.generate_class
    a = false
    delayer.new { a = delayer.busy? }

    assert_equal(false, a)
    assert_equal(false, delayer.busy?)
    delayer.run
    assert_equal(false, delayer.busy?)
    assert_equal(true, a)
  end

  def test_empty
    delayer = Delayer.generate_class
    a = false
    delayer.new { a = delayer.empty? }

    assert_equal(false, a)
    assert_equal(false, delayer.empty?)
    delayer.run
    assert_equal(true, delayer.empty?)
    assert_equal(true, a)
  end

  def test_size
    delayer = Delayer.generate_class
    a = 0
    assert_equal(0, delayer.size)
    delayer.new { a += 1 }
    assert_equal(1, delayer.size)
    delayer.new { a += 1 }
    delayer.new { a += 1 }
    assert_equal(3, delayer.size)
    delayer.run
    assert_equal(0, delayer.size)
  end

  def test_cancel_begin
    delayer = Delayer.generate_class
    a = 0
    d = delayer.new { a += 1 }
    delayer.new { a += 2 }
    delayer.new { a += 4 }

    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(6, a)
  end

  def test_cancel_center
    delayer = Delayer.generate_class
    a = 0
    delayer.new { a += 1 }
    d = delayer.new { a += 2 }
    delayer.new { a += 4 }

    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(5, a)
  end

  def test_cancel_end
    delayer = Delayer.generate_class
    a = 0
    delayer.new { a += 1 }
    delayer.new { a += 2 }
    d = delayer.new { a += 4 }

    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(3, a)
  end

  def test_priority_asc
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    buffer = []
    delayer.new(:high) { buffer << 1 }
    delayer.new(:middle) { buffer << 2 }
    delayer.new(:low) { buffer << 3 }
    delayer.run
    assert_equal([1,2,3], buffer)
  end

  def test_priority_desc
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    buffer = []
    delayer.new(:low) { buffer << 3 }
    delayer.new(:middle) { buffer << 2 }
    delayer.new(:high) { buffer << 1 }
    delayer.run
    assert_equal([1,2,3], buffer)
  end

  def test_priority_complex
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    buffer = []
    delayer.new(:high) { buffer << 1 }
    delayer.new(:middle) { buffer << 2 }
    delayer.new(:low) { buffer << 3 }
    delayer.new(:middle) { buffer << 4 }
    delayer.new(:high) { buffer << 5 }
    delayer.new(:middle) { buffer << 6 }
    delayer.new(:low) { buffer << 7 }
    delayer.new(:middle) { buffer << 8 }
    delayer.new(:high) { buffer << 9 }
    delayer.run
    assert_equal([1,5,9,2,4,6,8,3,7], buffer)

    buffer = []
    delayer.new(:high) { buffer << 1 }
    delayer.new(:low) { buffer << 2 }
    delayer.new(:high) { buffer << 3 }
    delayer.new(:low) { buffer << 4 }
    delayer.run
    assert_equal([1,3,2,4], buffer)
  end

  def test_priority_cancel_begin
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    a = 0
    d = delayer.new { a += 1 }
    delayer.new { a += 2 }
    delayer.new { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(6, a)

    a = 0
    d = delayer.new(:low) { a += 1 }
    delayer.new(:high) { a += 2 }
    delayer.new(:high) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(6, a)

    a = 0
    d = delayer.new(:high) { a += 1 }
    delayer.new(:low) { a += 2 }
    delayer.new(:low) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(6, a)
  end

  def test_priority_cancel_center
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    a = 0
    delayer.new { a += 1 }
    d = delayer.new { a += 2 }
    delayer.new { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(5, a)

    a = 0
    delayer.new(:low) { a += 1 }
    d = delayer.new(:high) { a += 2 }
    delayer.new(:low) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(5, a)

    a = 0
    delayer.new(:high) { a += 1 }
    d = delayer.new(:low) { a += 2 }
    delayer.new(:high) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(5, a)
  end

  def test_priority_cancel_end
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    a = 0
    delayer.new { a += 1 }
    delayer.new { a += 2 }
    d = delayer.new { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(3, a)

    a = 0
    delayer.new(:low) { a += 1 }
    delayer.new(:low) { a += 2 }
    d = delayer.new(:high) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(3, a)

    a = 0
    delayer.new(:high) { a += 1 }
    delayer.new(:high) { a += 2 }
    d = delayer.new(:low) { a += 4 }
    assert_equal(0, a)
    d.cancel
    delayer.run
    assert_equal(3, a)
  end

  def test_multithread_register
    delayer = Delayer.generate_class
    buffer = []
    threads = []
    10.times do
      threads << Thread.new do
        1000.times do |number|
          delayer.new { buffer << number }
        end
      end
    end
    delayer.run
    threads.each(&:join)
    delayer.run
    assert_equal(10000, buffer.size)
    assert_equal((0..999).inject(&:+)*10, buffer.inject(&:+))
  end

  def test_nested
    delayer = Delayer.generate_class
    buffer = []
    delayer.new { buffer << 1 }
    delayer.new do
      delayer.new { buffer << 3 }
      delayer.new do
        delayer.new { buffer << 5 }
        delayer.new { buffer << 6 }
      end
      delayer.new { buffer << 4 }
    end
    delayer.new { buffer << 2 }

    delayer.run
    assert_equal([1,2,3,4,5,6], buffer)
  end

  def test_remain_hook
    delayer = Delayer.generate_class expire: 0.01
    a = []
    delayer.register_remain_hook {
      a << :remain
    }
    delayer.new { a << 0 }
    delayer.new { a << 1; sleep 0.1 }
    delayer.new { a << 2 }

    delayer.run

    delayer.new { a << 3 }
    delayer.new { a << 4 }

    delayer.run

    assert_equal([:remain, 0, 1, :remain, 2, 3, 4], a)

  end

  def test_recursive_mainloop
    delayer = Delayer.generate_class
    a = 0
    delayer.new { a = 1 }

    assert_equal(0, delayer.stash_level)
    delayer.stash_enter!
    assert_equal(1, delayer.stash_level)

    delayer.new { a = 2 }

    assert_equal(0, a)
    delayer.run
    assert_equal(2, a)

    delayer.stash_exit!
    assert_equal(0, delayer.stash_level)

    delayer.run
    assert_equal(1, a)
  end

  def test_pop_recursive_mainloop_remain_jobs
    delayer = Delayer.generate_class
    delayer.stash_enter!
    delayer.new{ ; }
    assert_raise Delayer::RemainJobsError do
      delayer.stash_exit!
    end
  end

  def test_pop_recursive_mainloop_in_level_zero
    delayer = Delayer.generate_class
    assert_raise Delayer::NoLowerLevelError do
      delayer.stash_exit!
    end
  end

  def test_timer
    delayer = Delayer.generate_class expire: 0.01
    a = []
    delayer.new(delay: 0.01) { a << 0 }
    delayer.new { a << 1 }

    delayer.run

    delayer.new { a << 2 }
    sleep 0.1

    delayer.run

    delayer.new { a << 3 }

    delayer.run

    assert_equal([1, 2, 0, 3], a)
  end

  def test_timer_give_time
    delayer = Delayer.generate_class expire: 0.01
    a = []
    delayer.new(delay: Time.new) { a << 0 }

    delayer.run

    assert_equal([0], a)
  end

  def test_plural_timer
    delayer = Delayer.generate_class expire: 0.01
    a = []
    delayer.new(delay: 0.01) { a << 0 }
    delayer.new(delay: 0.11) { a << 1 }
    delayer.new { a << 2 }

    delayer.run

    delayer.new { a << 3 }
    sleep 0.1

    delayer.run
    sleep 0.1

    delayer.new { a << 4 }

    delayer.run

    assert_equal([2, 3, 0, 4, 1], a)
  end

  def test_many_timer
    delayer = Delayer.generate_class expire: 0.01
    a = []
    (0..10).to_a.shuffle.each do |i|
      delayer.new(delay: i / 100.0) { a << i }
    end

    sleep 0.1

    delayer.run

    assert_equal((0..10).to_a, a)
  end

  def test_cancel_timer
    delayer = Delayer.generate_class
    a = 0
    delayer.new(delay: 0.01) { a += 1 }
    d = delayer.new(delay: 0.01) { a += 2 }
    delayer.new(delay: 0.01) { a += 4 }

    assert_equal(0, a)
    d.cancel
    sleep 0.1
    delayer.run
    assert_equal(5, a)
  end

  def test_cancel_timer_after_expire
    delayer = Delayer.generate_class
    a = 0
    delayer.new(delay: 0.01) { a += 1 }
    d = delayer.new(delay: 0.01) { a += 2 }
    delayer.new{ d.cancel }
    delayer.new(delay: 0.01) { a += 4 }

    assert_equal(0, a)
    sleep 0.1
    delayer.run
    assert_equal(5, a)
  end

  def test_reserve_new_timer_after_cancel
    delayer = Delayer.generate_class
    a = 0
    delayer.new(delay: 0.01) { a += 1 }
    d = delayer.new(delay: 0.02) { a += 2 }
    d.cancel
    delayer.new(delay: 0.03) { a += 4 }

    assert_equal(0, a)
    sleep 0.1
    delayer.run
    assert_equal(5, a)
  end

end
