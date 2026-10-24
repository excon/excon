# frozen_string_literal: true

require_relative 'test_helper'

# Excon::Socket's read buffering, tested against fake backend sockets instead
# of a server, so each test controls exactly what each read returns.
module SocketTestHelpers
  # An Excon::Socket over a given backend socket, that counts calls to
  # read_nonblock and never connects or waits.
  class FakeExconSocket < Excon::Socket
    attr_reader :read_count

    def initialize(backend_socket, *)
      super(*)
      @read_count = 0
      @socket = backend_socket
    end

    def read_nonblock(*)
      @read_count += 1
      super
    end

    def connect; end

    # Don't wait; assume the socket is ready.
    def select_with_timeout(*); end
  end

  # A backend whose read_nonblock returns the given strings in turn, each
  # in reads of at most max_read_size bytes. An empty string between two
  # others raises Errno::EAGAIN; running out raises EOFError.
  #
  # sequence records what each read did: the number of bytes returned,
  # 'EAGAIN' or 'EOF'. out_buffers records the buffer passed to each read.
  class FakeNonblockSocket
    attr_reader :out_buffers, :sequence

    def initialize(nonblock_reads, max_read_size = nil)
      @max_read_size = max_read_size || Float::INFINITY
      @nonblock_reads = nonblock_reads.map(&:dup)
      @out_buffers = []
      @sequence = []
    end

    def read_nonblock(maxlen, buffer = nil)
      @out_buffers << buffer
      eof! if @nonblock_reads.empty?
      eagain! if @nonblock_reads.first.empty?

      chunk = @nonblock_reads.first
      ret = chunk.slice!(0, [maxlen || chunk.length, @max_read_size].min)
      @sequence << ret.length
      return ret unless buffer

      # Like IO#read_nonblock, fill the given buffer, keeping its encoding.
      buffer.clear
      buffer << ret
    end

    private

    def eagain!
      @nonblock_reads.shift
      eof! if @nonblock_reads.empty?
      @sequence << 'EAGAIN'
      raise Errno::EAGAIN
    end

    def eof!
      @sequence << 'EOF'
      raise EOFError
    end
  end

  # A blocking backend whose read raises the given error.
  class FakeBlockingSocket
    def initialize(error)
      @error = error
    end

    def read(_max_length)
      raise @error
    end
  end
end

# Nonblocking reads, included below once per chunk_size.
#
# Each test reads from backend reads separated by an EAGAIN (see
# FakeNonblockSocket), then checks what came back, how many times Excon called
# read_nonblock, and what the backend did on each read.
module NonblockReadTests
  include SocketTestHelpers

  def test_readline_reads_once_for_a_buffered_line
    socket, backend = sockets(["one\ntwo\n"])

    assert_equal "one\n", socket.readline
    assert_equal 1, socket.read_count
    assert_equal [8, 'EOF'], backend.sequence # read everything there was, then hit EOF
  end

  def test_readline_returns_buffered_lines_in_turn
    socket, backend = sockets(["one\ntwo\n"])

    assert_equal "one\n", socket.readline
    assert_equal "two\n", socket.readline # from the buffer, without reading again
    assert_equal 1, socket.read_count
    assert_equal [8, 'EOF'], backend.sequence
  end

  def test_readline_handles_a_line_split_across_reads
    socket, backend = sockets(%W[one\nt wo\n])

    assert_equal "one\n", socket.readline
    assert_equal "two\n", socket.readline # "t" from the buffer, "wo\n" from a second read
    assert_equal 2, socket.read_count
    assert_equal [5, 'EAGAIN', 3, 'EOF'], backend.sequence
  end

  def test_read_after_readline_returns_the_rest_of_the_buffer
    socket, backend = sockets(["one\ntwo\n"])

    assert_equal "one\n", socket.readline
    assert_equal "two\n", socket.read(6) # only 4 bytes left before EOF
    assert_equal 2, socket.read_count
    assert_equal [8, 'EOF'], backend.sequence # the second read is served from the buffer
  end

  def test_read_does_not_stop_at_eagain
    socket, backend = sockets(%w[one two])

    assert_equal 'one', socket.read
    assert_equal 'two', socket.read # EAGAIN after "one" is not EOF
    assert_equal 2, socket.read_count
    assert_equal [3, 'EAGAIN', 3, 'EOF'], backend.sequence
  end

  private

  def sockets(nonblock_reads)
    backend = FakeNonblockSocket.new(nonblock_reads)
    socket = FakeExconSocket.new(backend, nonblock: true, chunk_size: chunk_size)
    [socket, backend]
  end
end

class SocketNonblockReadTest < Minitest::Test
  include NonblockReadTests

  def chunk_size
    nil
  end
end

class SocketNonblockReadChunkSize512Test < Minitest::Test
  include NonblockReadTests

  def chunk_size
    512
  end
end

class SocketTest < Minitest::Test
  include SocketTestHelpers

  def test_blocking_read_reraises_ssl_errors
    error = OpenSSL::SSL::SSLError.new('SSL error')
    socket = FakeExconSocket.new(FakeBlockingSocket.new(error))

    raised = assert_raises(OpenSSL::SSL::SSLError) { socket.read }
    assert_same error, raised
  end

  # The backend returns at most 2 bytes per read, so filling a request takes
  # several reads. The first goes straight into the empty read buffer; each
  # later one should go into the same reused binary scratch buffer, not a new
  # string per read.

  def test_read_with_max_length_reuses_a_binary_append_buffer
    backend = FakeNonblockSocket.new(["abcd\xFFf".b], 2)
    socket = FakeExconSocket.new(backend, nonblock: true)

    result = socket.read(6)

    assert_equal "abcd\xFFf".b, result
    assert_equal Encoding::BINARY, result.encoding
    assert_reused_binary_append_buffer backend.out_buffers[1..]
  end

  def test_read_without_max_length_reuses_a_binary_append_buffer
    backend = FakeNonblockSocket.new(["ab\xFF".b], 2)
    socket = FakeExconSocket.new(backend, nonblock: true, chunk_size: 512)

    assert_equal "ab\xFF".b, socket.read(nil)
    assert_reused_binary_append_buffer backend.out_buffers[1..]
  end

  private

  def assert_reused_binary_append_buffer(append_buffers)
    assert_equal 2, append_buffers.length
    scratch = append_buffers.first
    refute_nil scratch
    append_buffers.each do |buffer|
      assert_same scratch, buffer
      assert_equal Encoding::BINARY, buffer.encoding
    end
  end
end
