module Excon
  class Request
    CR_NL     = "\r\n"
    HTTP_1_1  = " HTTP/1.1\r\n"
    FORCE_ENC = CR_NL.respond_to?(:force_encoding)

    def initialize(connection, params)
      @connection = connection
      @params = params.dup

      @params[:headers] = @connection.attributes[:headers].merge(@params[:headers] || {})
      @params[:headers]['Host'] ||= '' << @params[:host] << ':' << @params[:port]
      @params[:path].insert(0, '/') unless @params[:path][0, 1] == '/'
    end

    def invoke(&block)
      invoke_with_retries(@params[:retry_limit], &block)
    end

    def invoke_with_retries(retries_remaining, &block)
      try_request(&block)
    rescue => request_error
      if @params[:idempotent] && [Excon::Errors::SocketError, Excon::Errors::HTTPStatusError].any? {|ex| request_error.kind_of? ex }
        retries_remaining -= 1
        if retries_remaining > 0
          if @params[:body].respond_to?(:pos=)
            @params[:body].pos = 0
          end
          retry
        else
          raise(request_error)
        end
      else
        raise(request_error)
      end
    end

    def socket
      @connection.socket
    end

    def process_mock(&block)
      @connection.invoke_stub(@params, &block)
    end

    def add_query(request)
      case @params[:query]
      when String
        request << '?' << @params[:query]
      when Hash
        request << '?'
        for key, values in @params[:query]
          if values.nil?
            request << key.to_s << '&'
          else
            for value in [*values]
              request << key.to_s << '=' << CGI.escape(value.to_s) << '&'
            end
          end
        end
        request.chop! # remove trailing '&'
      end
    end

    def set_content_length
      unless @params[:headers].has_key?('Content-Length')
        @params[:headers]['Content-Length'] = case @params[:body]
        when File
          @params[:body].binmode
          File.size(@params[:body])
        when String
          if FORCE_ENC
            @params[:body].force_encoding('BINARY')
          end
          @params[:body].length
        else
          0
        end
      end
    end

    def write_out_body
      if @params[:body]
        if @params[:body].is_a?(String)
          socket.write(@params[:body])
        else
          while chunk = @params[:body].read(CHUNK_SIZE)
            socket.write(chunk)
          end
        end
      end
    end

    def request_string
      @request_string ||= begin
        request = @params[:method].to_s.upcase << ' '
        request << @params[:scheme] << '://' << @params[:host] << ':' << @params[:port] if @proxy
        request << @params[:path]

        add_query(request)
        request << HTTP_1_1

        set_content_length
        for key, values in @params[:headers]
          for value in [*values]
            request << key.to_s << ': ' << value.to_s << CR_NL
          end
        end

        # add additional "\r\n" to indicate end of headers
        request << CR_NL
        request
      end
    end

    def try_request(&block)
      begin
        return process_mock(&block) if @params[:mock]
        socket.params = @params

        socket.write(request_string)
        write_out_body
        response = Excon::Response.parse(socket, @params, &block)

        if response.headers['Connection'] == 'close'
          @connection.reset
        end

        response
      rescue Excon::Errors::StubNotFound => stub_not_found
        raise(stub_not_found)
      rescue => socket_error
        @connection.reset
        raise(Excon::Errors::SocketError.new(socket_error))
      end

      if @params.has_key?(:expects) && ![*@params[:expects]].include?(response.status)
        @connection.reset
        raise(Excon::Errors.status_error(@params, response))
      else
        response
      end
    end
  end
end

