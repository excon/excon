Shindo.tests('HTTPStatusError request/response debugging') do

  with_server('error') do

    tests('message does not include response or response info').returns(true) do
      begin
        Excon.get('http://127.0.0.1:9292/error/not_found', :expects => 200)
      rescue => err
        err.message.include?('Expected(200) <=> Actual(404 Not Found)') &&
        !err.message.include?('request =>') &&
        !err.message.include?('response =>')
      end
    end

    tests('message includes only response info').returns(true) do
      begin
        Excon.get('http://127.0.0.1:9292/error/not_found', :expects => 200,
                  :debug_response => true)
      rescue => err
        err.message.include?('Expected(200) <=> Actual(404 Not Found)') &&
        !err.message.include?('request =>') &&
        !!(err.message =~ /response =>(.*)server says not found/)
      end
    end

    tests('message includes only request info').returns(true) do
      begin
        Excon.get('http://127.0.0.1:9292/error/not_found', :expects => 200,
                  :debug_request => true)
      rescue => err
        err.message.include?('Expected(200) <=> Actual(404 Not Found)') &&
        !!(err.message =~ /request =>(.*)error\/not_found/) &&
        !err.message.include?('response =>')
      end
    end

    tests('message include request and response info').returns(true) do
      begin
        Excon.get('http://127.0.0.1:9292/error/not_found', :expects => 200,
                  :debug_request => true, :debug_response => true)
      rescue => err
        err.message.include?('Expected(200) <=> Actual(404 Not Found)') &&
        !!(err.message =~ /request =>(.*)not_found/) &&
        !!(err.message =~ /response =>(.*)server says not found/)
      end
    end

  end
end
