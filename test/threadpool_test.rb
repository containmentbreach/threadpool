require 'test/unit'
require 'lib/threadpool'


class ThreadPoolTest < Test::Unit::TestCase
  def setup
  end

  def test_me
    @pool = ThreadPool.new(2, 15, 1)
    n = 0
    p = proc {|x| n += x }
    100.times {|i| @pool.run(i, &p) }
    @pool.close
    assert_equal 4950, n
  end
end

