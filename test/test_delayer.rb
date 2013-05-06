# -*- coding: utf-8 -*-

require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'delayer'

class TestDelayer < Test::Unit::TestCase
  def test_delayed
    delayer = Delayer.generate_class
    a = 0
    delayer.new { a = 1 }

    assert_equal(0, a)
    delayer.run
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

  # def test_priority
  #   delayer = Delayer.generate_class(priority: [:high, :middle, :low],
  #                                    default: :middle)
  #   buffer = []
  #   delayer.new(:low) { buffer << 1 }
  #   delayer.new(:middle) { buffer << 2 }
  #   delayer.new(:high) { buffer << 3 }
  #   delayer.new(:middle) { buffer << 4 }
  #   delayer.new(:low) { buffer << 5 }
  #   delayer.run
  #   assert_equal([3,2,4,1,5], buffer)
  # end
end
