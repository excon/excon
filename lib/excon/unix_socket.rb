module Excon
  class UnixSocket

    extend Forwardable

    attr_accessor :data

    def params
      Excon.display_warning("Excon::Socket#params is deprecated use Excon::Socket#data instead (#{caller.first})")
      @data
    end
    def params=(new_params)
      Excon.display_warning("Excon::Socket#params= is deprecated use Excon::Socket#data= instead (#{caller.first})")
      @data = new_params
    end

    attr_reader :remote_ip

    def_delegators(:@socket, :close,    :close)
    def_delegators(:@socket, :readline, :readline)

    def initialize(data = {})
      @data = data
      @read_buffer = ''
      @eof = false

      connect
    end

    def read(max_length=nil)
      if @eof
        return nil
      elsif @data[:nonblock]
        begin
          if max_length
            until @read_buffer.length >= max_length
              @read_buffer << @socket.read_nonblock(max_length - @read_buffer.length)
            end
          else
            while true
              @read_buffer << @socket.read_nonblock(@data[:chunk_size])
            end
          end
        rescue OpenSSL::SSL::SSLError => error
          if error.message == 'read would block'
            if IO.select([@socket], nil, nil, @data[:read_timeout])
              retry
            else
              raise(Excon::Errors::Timeout.new("read timeout reached"))
            end
          else
            raise(error)
          end
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable
          if IO.select([@socket], nil, nil, @data[:read_timeout])
            retry
          else
            raise(Excon::Errors::Timeout.new("read timeout reached"))
          end
        rescue EOFError
          @eof = true
        end
        if max_length
          @read_buffer.slice!(0, max_length)
        else
          # read until EOFError, so return everything
          @read_buffer.slice!(0, @read_buffer.length)
        end
      else
        begin
          Timeout.timeout(@data[:read_timeout]) do
            @socket.read(max_length)
          end
        rescue Timeout::Error
          raise Excon::Errors::Timeout.new('read timeout reached')
        end
      end
    end

    def write(data)
      if @data[:nonblock]
        if FORCE_ENC
          data.force_encoding('BINARY')
        end
        while true
          written = nil
          begin
            # I wish that this API accepted a start position, then we wouldn't
            # have to slice data when there is a short write.
            written = @socket.write_nonblock(data)
          rescue OpenSSL::SSL::SSLError, Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable => error
            if error.is_a?(OpenSSL::SSL::SSLError) && error.message != 'write would block'
              raise error
            else
              if IO.select(nil, [@socket], nil, @data[:write_timeout])
                retry
              else
                raise Excon::Errors::Timeout.new('write timeout reached')
              end
            end
          end

          # Fast, common case.
          break if written == data.size

          # This takes advantage of the fact that most ruby implementations
          # have Copy-On-Write strings. Thusly why requesting a subrange
          # of data, we actually don't copy data because the new string
          # simply references a subrange of the original.
          data = data[written, data.size]
        end
      else
        begin
          Timeout.timeout(@data[:write_timeout]) do
            @socket.write(data)
          end
        rescue Timeout::Error
          Excon::Errors::Timeout.new('write timeout reached')
        end
      end
    end

    private

    def connect
      @socket = nil
      exception = nil

      begin
        socket = ::UNIXSocket.new(@data[:path])

        @socket = socket
      rescue Errno::ECONNREFUSED => exception
        socket.close if socket
        raise
      end

      if @data[:tcp_nodelay]
        @socket.setsockopt(::Socket::IPPROTO_TCP,
                           ::Socket::TCP_NODELAY,
                           true)
      end
    end

  end
end
