# A fake Excon::Socket that allows passing in an arbitrary backend @socket
class MockExconSocket < Excon::Socket
  attr_reader :read_count

  def initialize(backend_socket, *args)
    super(*args)
    @read_count = 0
    @socket = backend_socket
  end

  def read_nonblock(*args)
    @read_count += 1
    super
  end

  def connect
    # pass
  end

  def select_with_timeout(*args)
    # don't actually wait, assume we're ready
  end
end

# A socket whose read_nonblock returns from an input list,
# and which counts the number of reads
class MockNonblockRubySocket
  attr_reader :sequence

  def initialize(nonblock_reads)
    @nonblock_reads = nonblock_reads
    @sequence = []
  end

  def read_nonblock(maxlen)
    if @nonblock_reads.empty?
      @sequence << 'EOF'
      raise EOFError
    elsif @nonblock_reads.first.empty?
      @nonblock_reads.shift
      if @nonblock_reads.empty?
        @sequence << 'EOF'
        raise EOFError
      end
      @sequence << 'EAGAIN'
      raise Errno::EAGAIN
    elsif
      len = maxlen ? maxlen : @nonblock_reads.first.length
      ret = @nonblock_reads.first.slice!(0, len)
      @sequence << ret.length
      ret
    end
  end

  # Returns the results of `block`, as well as how many times we called read on the Excon
  # socket, and the sequence of reads on the backend socket
  def self.check_reads(nonblock_reads, socket_args, &block)
    backend_socket = MockNonblockRubySocket.new(nonblock_reads)
    socket = MockExconSocket.new(backend_socket, { nonblock: true }.merge(socket_args))
    ret = block[socket]
    [ret, socket.read_count, backend_socket.sequence]
  end
end

Shindo.tests('socket') do
  CHUNK_SIZES = [nil, 512]
  CHUNK_SIZES.each do |chunk_size|
    tests("chunk_size: #{chunk_size}") do
      socket_args = {chunk_size: chunk_size}
      tests('read_nonblock') do
        tests('readline nonblock is efficient') do
          returns(["one\n", 1, [8, 'EOF']]) do
            MockNonblockRubySocket.check_reads(["one\ntwo\n"], socket_args) do |sock|
              sock.readline
            end
          end
        end

        tests('readline nonblock works sequentially') do
          returns([["one\n", "two\n"], 1, [8, 'EOF']]) do
            MockNonblockRubySocket.check_reads(["one\ntwo\n"], socket_args) do |sock|
              2.times.map { sock.readline }
            end
          end
        end

        tests('readline nonblock can handle partial reads') do
          returns([["one\n", "two\n"], 2, [5, 'EAGAIN', 3, 'EOF']]) do
            MockNonblockRubySocket.check_reads(["one\nt", "wo\n"], socket_args) do |sock|
              2.times.map { sock.readline }
            end
          end
        end

        tests('readline nonblock before read') do
          returns([["one\n", "two\n"], 2, [8, 'EOF']]) do
          MockNonblockRubySocket.check_reads(["one\ntwo\n"], socket_args) do |sock|
              [sock.readline, sock.read(6)]
            end
          end
        end

        tests('read_nonblock does not EOF early') do
          returns([["one", "two"], 2, [3, 'EAGAIN', 3, 'EOF']]) do
            # Data, EAGAIN, data, EOF
            MockNonblockRubySocket.check_reads(["one", "two"], socket_args) do |sock|
              [sock.read, sock.read]
            end
          end
        end
      end
    end
  end
end
