require 'thread'
require 'thwait'
require 'monitor'

# This is unsurprisingly a thread pool.
# It can run your jobs asynchronously.
# It can grow and shrink depending on the load.
# Like any good pool it can be... closed!
class ThreadPool
  DEFAULT_CORE_WORKERS = 4
  DEFAULT_KEEP_ALIVE_TIME = 5

  class Job #:nodoc:
    def initialize(*args, &handler)
      @args, @handler = args, handler
    end
  
    def run
      @handler.call(*@args)
    end
  end

  @@controllers = ThreadGroup.new

  #    new([core_workers[, max_workers[, keep_alive_time]]], options]) [{|pool| ... }]
  #
  # === Arguments
  # [+core_workers+]    Number of core worker threads. The pool will never shrink below this point.
  # [+max_workers+]     Maximum number of worker threads allowed per this pool.
  #                     The pool will never expand over this limit.
  #                     Default is +core_workers * 2+
  # [+keep_alive_time+] Time to keep non-core workers alive. Default is 5 sec.
  # [+options+]         +:init_core+ => false to defer initial setup of core workers.
  # 
  # When called with a block the pool will be closed upon exit from the block.
  # Graceful +close+ will be used, a non-bang version.
  #
  # === Example:
  #   ThreadPool.new 10, 25, 6.7, :init_core => false do |pool|
  #   ...
  #   end
  def initialize(*args)
    extend MonitorMixin
    
    options = args.last.is_a?(Hash) ? args.pop : {}

    @core_workers = (args[0] || DEFAULT_CORE_WORKERS).to_i
    raise ArgumentError, "core_workers must be a positive integer" if @core_workers <= 0
    
    @max_workers = (args[1] || @core_workers * 2).to_i
    raise ArgumentError, "max_workers must be >= core_workers" if @max_workers < @core_workers

    @keep_alive_time = (args[2] || DEFAULT_KEEP_ALIVE_TIME).to_f
    raise ArgumentError, "keep_alive_time must be a non-negative real number" if @keep_alive_time < 0

    @workers, @jobs = ThreadGroup.new, Queue.new

    @worker_routine = proc do
      while job = @jobs.pop
        job.run rescue nil
      end
    end
    
    @controller = Thread.new do
      loop do
        sleep(@keep_alive_time)
        break if @dead
        synchronize do
          n = @jobs.num_waiting - @core_workers
          stop_workers([n / 2, 1].max) if n >= 0
        end
      end
    end
    @@controllers.add(@controller)
    
    create_workers(@core_workers) if options.fetch(:init_core, true)
    
    begin
      yield self
    ensure
      shutdown
    end if block_given?
  end
  
  #    live? => boolean
  #
  # Pool is live when it's not dead.
  # Pool is dead when it's closed.
  def live?
    synchronize { !@dead }
  end
  
  #    run([arg1[, arg2[, ...]]]) {|[arg1[, arg2[, ...]]]| ... } -> pool
  #
  # Schedule the block to run asynchronously on a worker thread. Return immediately.
  # Any arguments passed to this method will be passed to the block.
  #
  # When there are no idle workers the pool will grow.
  # When max pool size is reached the job will be queued up until better times.
  #
  # === Example:
  #   pool.run('go to hell') do |greeting|
  #     puts greeting
  #   end
  def run(*args, &block)
    run_core(true, *args, &block)
  end
  
  #    try_run([arg1[, arg2[, ...]]]) {|[arg1[, arg2[, ...]]]| ... } -> pool or nil
  #
  # Try to run the block asynchronously on a worker thread (see +run+).
  # If there are no idle workers immediately available and the pool reached its maximum size,
  # then do not rape enqueue the job and return +nil+.
  #
  # === Example:
  #   puts 'zomg' unless pool.try_run('go to hell') {|greeting| puts greeting }
  def try_run(*args, &block)
    run_core(false, *args, &block)
  end
  
  #    close
  #
  # Rape me tenderly. Waits until all the jobs are done and destroys the pool.
  def close
    _sync do
      @dead = true
      @controller.run
      stop_workers(@workers.list.size)
    end
    ThreadsWait.all_waits(@controller, *@workers.list)
    self
  end
  
  #    close!
  #
  # Rape me hard. Instantly kills the workers. Ensure blocks will be called though (last prayer on).
  def close!
    _sync do
      @dead = true
      @controller.run
      @workers.list.each {|w| w.kill }
    end
    self
  end

  alias rape! close!

  private
  
  def run_core(enqueue, *args, &block) #:nodoc:
    raise ArgumentError, 'block must be provided' unless block_given?
    _sync do
      if @jobs.num_waiting == 0
        if @workers.list.size < @max_workers
          create_worker
        else
          return nil unless enqueue
        end
      end
      @jobs.push(Job.new(*args, &block))
    end
    self
  end

  def _sync #:nodoc:
    synchronize do
      check_state
      yield
    end
  end

  def check_state #:nodoc:
    raise "pool's closed" if @dead
  end

  def create_worker #:nodoc:
    @workers.add(Thread.new(&@worker_routine))
  end

  def create_workers(n) #:nodoc:
    n.times { create_worker }
  end

  def stop_workers(n) #:nodoc:
    n.times { @jobs << nil }
  end
end

