# -*- coding: utf-8 -*-

require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'delayer'

class TestPriorityDelayer < Test::Unit::TestCase
  def test_asc
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    buffer = []
    delayer.new(:high) { buffer << 1 }
    delayer.new(:middle) { buffer << 2 }
    delayer.new(:low) { buffer << 3 }
    delayer.run
    assert_equal([1,2,3], buffer)
  end

  def test_desc
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle)
    buffer = []
    delayer.new(:low) { buffer << 3 }
    delayer.new(:middle) { buffer << 2 }
    delayer.new(:high) { buffer << 1 }
    delayer.run
    assert_equal([1,2,3], buffer)
  end

  def test_complex
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

  def test_timelimited
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                                     default: :middle,
                                     expire: 0.01)
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
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                           default: :middle)
    a = false
    delayer.new { a = delayer.busy? }

    assert_equal(false, a)
    assert_equal(false, delayer.busy?)
    delayer.run
    assert_equal(false, delayer.busy?)
    assert_equal(true, a)
  end

  def test_empty
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                           default: :middle)
    a = false
    delayer.new { a = delayer.empty? }

    assert_equal(false, a)
    assert_equal(false, delayer.empty?)
    delayer.run
    assert_equal(true, delayer.empty?)
    assert_equal(true, a)
  end

  def test_size
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                           default: :middle)
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

  def test_cancel_center
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

  def test_cancel_end
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
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                           default: :middle)
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
    delayer = Delayer.generate_class(priority: [:high, :middle, :low],
                           default: :middle)
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

  def test_invalid_priority
    delayer = Delayer.generate_class(priority: [:high, :middle, :low])
    buffer = []
    assert_raise Delayer::InvalidPriorityError do
      delayer.new(0) { buffer << 1 }
    end
    assert_raise Delayer::InvalidPriorityError do
      delayer.new("middle") { buffer << 2 }
    end
    assert_raise Delayer::InvalidPriorityError do
      delayer.new { buffer << 3 }
    end
    delayer.run
    assert_equal([], buffer)
  end
end
