# frozen_string_literal: true

# A minimal fiber scheduler that records which hooks Ruby calls, so tests can
# check how excon waits on sockets when a scheduler is set. It runs one fiber
# at a time and waits by blocking the thread, which is enough for a request
# made from a single fiber.
#
#   scheduler = RecordingScheduler.new
#   RecordingScheduler.run(scheduler) { Excon.get('http://127.0.0.1:9292/') }
#   scheduler.calls # => [:io_wait, ...]
#
# Like Async, io_wait returns false when the timeout is reached.
class RecordingScheduler
  attr_reader :calls

  # Runs the block in a non-blocking fiber of a new thread with the scheduler
  # set, and returns its value (or raises its error).
  def self.run(scheduler)
    thread = Thread.new do
      Thread.current.report_on_exception = false
      Fiber.set_scheduler(scheduler)
      result = nil
      Fiber.schedule { result = yield }
      result
    end
    thread.value
  end

  def initialize
    @calls = []
  end

  def io_wait(io, events, timeout)
    @calls << :io_wait
    readers = [io] if events.anybits?(IO::READABLE)
    writers = [io] if events.anybits?(IO::WRITABLE)
    Fiber.blocking { IO.select(readers, writers, nil, timeout) } ? events : false
  end

  def io_select(readers, writers, errors, timeout)
    @calls << :io_select
    Fiber.blocking { IO.select(readers, writers, errors, timeout) }
  end

  def kernel_sleep(duration = nil)
    Fiber.blocking { duration ? sleep(duration) : sleep }
  end

  # With only one fiber, nothing could wake a blocked one.
  def block(blocker, _timeout = nil)
    raise NotImplementedError, "RecordingScheduler can't block on #{blocker.inspect}"
  end

  def unblock(_blocker, _fiber); end

  # Ruby 4.0+ calls this to interrupt a blocked fiber (as when another thread
  # closes an IO it waits on), which these tests don't do; 4.1 requires it.
  def fiber_interrupt(_fiber, exception)
    raise NotImplementedError, "RecordingScheduler can't interrupt a fiber with #{exception.inspect}"
  end

  def fiber(&)
    Fiber.new(blocking: false, &).tap(&:resume)
  end
end
