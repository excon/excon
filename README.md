excon
=====

Http(s) EXtended CONnections

[![Build Status](https://secure.travis-ci.org/geemus/excon.png)](http://travis-ci.org/geemus/excon)
[![Dependency Status](https://gemnasium.com/geemus/excon.png)](https://gemnasium.com/geemus/excon)

Getting Started
---------------

Install the gem.

    $ sudo gem install excon

Require with rubygems.

    require 'rubygems'
    require 'excon'

The simplest way to use excon is with one-off requests:

    response = Excon.get('http://geemus.com')

Supported one-off request methods are #connect, #delete, #get, #head, #options, #post, #put, and #trace.

The returned response object has #body, #headers and #status attributes.

Alternately you can create a connection object which is reusable across multiple requests (more performant!).

    connection = Excon.new('http://geemus.com')
    response_one = connection.get
    response_two = connection.post(:path => '/foo')
    response_three = connection.delete(:path => '/bar')

Sometimes it is more convenient to specify the request type as an argument:

    response_four = connection.request(:method => :get, :path => '/more')

Both one-off and persistent connections support many other options. Here are a few common examples:

    # Custom headers
    Excon.get('http://geemus.com', :headers => {'Authorization' => 'Basic 0123456789ABCDEF'})
    connection.get(:headers => {'Authorization' => 'Basic 0123456789ABCDEF'})

    # Changing query strings
    connection = Excon.new('http://geemus.com/')
    connection.get(:query => {:foo => 'bar'})

    # POST body
    Excon.post('http://geemus.com', :body => 'language=ruby&class=fog')

    # request accepts either symbols or strings
    connection.request(:method => :get)
    connection.request(:method => 'GET')

These options can be combined to make pretty much any request you might need.

Excon can also expect one or more HTTP status code in response, raising an exception if the response does not meet the criteria.

If you need to accept as response one or more HTTP status codes you can declare them in an array:

    connection.request(expects => [200, 201], :method => :get, :path => path, :query => {})

Chunked Requests
----------------

You can make `Transfer-Encoding: chunked` requests by passing a block that will deliver chunks, delivering an empty chunk to signal completion.

    file = File.open('data')

    chunker = lambda do
      # Excon::CHUNK_SIZE defaults to 1048576, ie 1MB
      # to_s will convert the nil receieved after everything is read to the final empty chunk
      file.read(Excon::CHUNK_SIZE).to_s
    end

    Excon.post('http://geemus.com', :request_block => chunker)

    file.close

Iterating in this way allows you to have more granular control over writes and to write things where you can not calculate the overall length up front.

Streaming Responses
-------------------

You can stream responses by passing a block that will receive each chunk.

    streamer = lambda do |chunk, remaining_bytes, total_bytes|
      puts chunk
      puts "Remaining: #{remaining_bytes.to_f / total_bytes}%"
    end

    Excon.get('http://geemus.com', :response_block => streamer)

Iterating over each chunk will allow you to do work on the response incrementally without buffering the entire response first. For very large responses this can lead to significant memory savings.

Proxy Support
-------------

You can specify a proxy URL that Excon will use with both HTTP and HTTPS connections:

    connection = Excon.new('http://geemus.com', :proxy => 'http://my.proxy:3128')
    connection.request(:method => 'GET')

The proxy URL must be fully specified, including scheme (e.g. "http://") and port.

Proxy support must be set when establishing a connection object and cannot be overridden in individual requests. Because of this it is unavailable in one-off requests (Excon.get, etc.)

NOTE: Excon will use the environment variables `http_proxy` and `https_proxy` if they are present. If these variables are set they will take precedence over a :proxy option specified in code. If "https_proxy" is not set, the value of "http_proxy" will be used for both HTTP and HTTPS connections.

Stubs
-----

You can stub out requests for testing purposes by enabling mock mode on a connection.

    connection = Excon.new('http://example.com', :mock => true)

Or by enabling mock mode for a request.

    connection.request(:method => :get, :path => 'example', :mock => true)

Then you can add stubs, for instance:

    # Excon.stub(request_attributes, response_attributes)
    Excon.stub({:method => :get}, {:body => 'body', :status => 200})

Omitted attributes are assumed to match, so this stub will match any get request and return an Excon::Response with a body of 'body' and status of 200.  You can add whatever stubs you might like this way and they will be checked against in the order they were added, if none of them match then excon will raise an error to let you know.

Alternatively you can pass a block instead of `response_attributes` and it will be called with the request params.  For example, you could create a stub that echoes the body given to it like this:

    # Excon.stub(request_attributes, &response_block)
    Excon.stub({:method => :put}) do |params|
      {:body => params[:body], :status => 200}
    end

In order to clear previously defined stubs you can use:

    Excon.stubs.clear

For example, if using RSpec for your test suite you can clear stubs after running each example:

    config.after(:each) do
        Excon.stubs.clear
    end

HTTPS/SSL Issues
----------------

By default excon will try to verify peer certificates when using SSL for HTTPS. Unfortunately on some operating systems the defaults will not work. This will likely manifest itself as something like `Excon::Errors::SocketError: SSL_connect returned=1 ...`

If you have the misfortune of running into this problem you have a couple options. If you have certificates but they aren't being auto-discovered, you can specify the path to your certificates:

    Excon.ssl_ca_path = '/path/to/certs'

Failing that, you can turn off peer verification (less secure):

    Excon.ssl_verify_peer = false

Either of these should allow you to work around the socket error and continue with your work.

Instrumentation
---------------

Excon calls can be timed using the [ActiveSupport::Notifications](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) API.

    connection = Excon.new('http://geemus.com',
        :instrumentor => ActiveSupport::Notifications)

Excon will then instrument each request, retry, and error.  The corresponding events are named excon.request, excon.retry, and excon.error respectively.

    ActiveSupport::Notifications.subscribe(/excon/) do |*args|
      puts "Excon did stuff!"
    end

If you prefer to label each event with something other than "excon," you may specify
an alternate name in the constructor:

    connection = Excon.new('http://geemus.com',
        :instrumentor => ActiveSupport::Notifications,
        :instrumentor_name => 'my_app')

If you don't want to add activesupport to your application, simply define a class which implements the same #instrument method like so:

    class SimpleInstrumentor
      class << self
        attr_accessor :events

        def instrument(name, params = {}, &block)
          puts "#{name} just happened."
          yield if block_given?
        end
      end
    end

The #instrument method will be called for each HTTP request, retry, and error.

See [the documentation for ActiveSupport::Notifications](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) for more detail on using the subscription interface.  See excon's instrumentation_test.rb for more examples of instrumenting excon.

Copyright
---------

(The MIT License)

Copyright (c) 2010-2011 {geemus (Wesley Beary)}[http://github.com/geemus]

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
