excon
=====

Usable, fast, simple Ruby HTTP 1.1

Excon was designed to be simple, fast and performant. It works great as a general HTTP(s) client and is particularly well suited to usage in API clients.

[![Build Status](https://secure.travis-ci.org/geemus/excon.png)](http://travis-ci.org/geemus/excon)
[![Dependency Status](https://gemnasium.com/geemus/excon.png)](https://gemnasium.com/geemus/excon)
[![Gem Version](https://fury-badge.herokuapp.com/rb/excon.png)](http://badge.fury.io/rb/excon)

Getting Started
---------------

Install the gem.

```
$ sudo gem install excon
```

Require with rubygems.

```ruby
require 'rubygems'
require 'excon'
```

The easiest way to get started is by using one-off requests. Supported one-off request methods are `connect`, `delete`, `get`, `head`, `options`, `post`, `put`, and `trace`. Requests return a response object which has `body`, `headers`, `remote_ip` and `status` attributes.

```ruby
response = Excon.get('http://geemus.com')
response.body       # => "..."
response.headers    # => {...}
response.remote_ip  # => "..."
response.status     # => 200
```

For API clients or other ongoing usage, reuse a connection across multiple requests to share options and improve performance.

```ruby
connection = Excon.new('http://geemus.com')
get_response = connection.get
post_response = connection.post(:path => '/foo')
delete_response = connection.delete(:path => '/bar')
```

Options
-------

Both one-off and persistent connections support many other options. The final options for a request are built up by starting with `Excon.defaults`, then merging in options from the connection and finally merging in any request options. In this way you have plenty of options on where and how to set options and can easily setup connections or defaults to match common options for a particular endpoint.

Here are a few common examples:

```ruby
# Custom headers
Excon.get('http://geemus.com', :headers => {'Authorization' => 'Basic 0123456789ABCDEF'})
connection.get(:headers => {'Authorization' => 'Basic 0123456789ABCDEF'})

# Changing query strings
connection = Excon.new('http://geemus.com/')
connection.get(:query => {:foo => 'bar'})

# POST body encoded with application/x-www-form-urlencoded
Excon.post('http://geemus.com',
  :body => 'language=ruby&class=fog',
  :headers => { "Content-Type" => "application/x-www-form-urlencoded" })

# same again, but using URI to build the body of parameters
Excon.post('http://geemus.com',
  :body => URI.encode_www_form(:language => 'ruby', :class => 'fog'),
  :headers => { "Content-Type" => "application/x-www-form-urlencoded" })

# request takes a method option, accepting either a symbol or string
connection.request(:method => :get)
connection.request(:method => 'GET')

# expect one or more status codes, or raise an error
connection.request(:expects => [200, 201], :method => :get)

# this request can be repeated safely, so retry on errors up to 3 times
connection.request(:idempotent => true)

# this request can be repeated safely, retry up to 6 times
connection.request(:idempotent => true, :retry_limit => 6)

# opt-out of nonblocking operations for performance and/or as a workaround
connection.request(:nonblock => false)

# set longer read_timeout (default is 60 seconds)
connection.request(:read_timeout => 360)

# set longer write_timeout (default is 60 seconds)
connection.request(:write_timeout => 360)

# Enable the socket option TCP_NODELAY on the underlying socket.
#
# This can improve response time when sending frequent short
# requests in time-sensitive scenarios.
#
connection = Excon.new('http://geemus.com/', :tcp_nodelay => true)

# opt-in to omitting port from http:80 and https:443
connection = Excon.new('http://geemus.com/', :omit_default_port => true)

# set longer connect_timeout (default is 60 seconds)
connection = Excon.new('http://geemus.com/', :connect_timeout => 360)
```

Chunked Requests
----------------

You can make `Transfer-Encoding: chunked` requests by passing a block that will deliver chunks, delivering an empty chunk to signal completion.

```ruby
file = File.open('data')

chunker = lambda do
  # Excon.defaults[:chunk_size] defaults to 1048576, ie 1MB
  # to_s will convert the nil received after everything is read to the final empty chunk
  file.read(Excon.defaults[:chunk_size]).to_s
end

Excon.post('http://geemus.com', :request_block => chunker)

file.close
```

Iterating in this way allows you to have more granular control over writes and to write things where you can not calculate the overall length up front.

Pipelining Requests
------------------

You can make use of HTTP pipelining to improve performance. Instead of the normal request/response cyle, pipelining sends a series of requests and then receives a series of responses. You can take advantage of this using the `requests` method, which takes an array of params where each is a hash like request would receive and returns an array of responses.

```ruby
connection = Excon.new('http://geemus.com/')
connection.requests([{:method => :get}, {:method => :get}])
```

Streaming Responses
-------------------

You can stream responses by passing a block that will receive each chunk.

```ruby
streamer = lambda do |chunk, remaining_bytes, total_bytes|
  puts chunk
  puts "Remaining: #{remaining_bytes.to_f / total_bytes}%"
end

Excon.get('http://geemus.com', :response_block => streamer)
```

Iterating over each chunk will allow you to do work on the response incrementally without buffering the entire response first. For very large responses this can lead to significant memory savings.

Proxy Support
-------------

You can specify a proxy URL that Excon will use with both HTTP and HTTPS connections:

```ruby
connection = Excon.new('http://geemus.com', :proxy => 'http://my.proxy:3128')
connection.request(:method => 'GET')

Excon.get('http://geemus.com', :proxy => 'http://my.proxy:3128')
```

The proxy URL must be fully specified, including scheme (e.g. "http://") and port.

Proxy support must be set when establishing a connection object and cannot be overridden in individual requests.

NOTE: Excon will use the environment variables `http_proxy` and `https_proxy` if they are present. If these variables are set they will take precedence over a :proxy option specified in code. If "https_proxy" is not set, the value of "http_proxy" will be used for both HTTP and HTTPS connections.

Unix Socket Support
------------------

The Unix socket will work for one-off requests and multiuse connections.  A Unix socket path must be provided separate from the resource path.

```ruby
connection = Excon.new('unix:///', :socket => '/tmp/unicorn.sock')
connection.request(:method => :get, :path => '/ping')

Excon.get('unix:///ping', :socket => '/tmp/unicorn.sock')
```

NOTE: Proxies will be ignored when using a Unix socket, since a Unix socket has to be local.

Stubs
-----

You can stub out requests for testing purposes by enabling mock mode on a connection.

```ruby
connection = Excon.new('http://example.com', :mock => true)
```

Or by enabling mock mode for a request.

```ruby
connection.request(:method => :get, :path => 'example', :mock => true)
```

Add stubs by providing the request_attributes to match and response attributes to return. Response params can be specified as either a hash or block which will yield with response_params.

```ruby
Excon.stub({}, {:body => 'body', :status => 200})
Excon.stub({}, lambda {|request_params| :body => request_params[:body], :status => 200})
```

Omitted attributes are assumed to match, so this stub will match *any* request and return an Excon::Response with a body of 'body' and status of 200.  You can add whatever stubs you might like this way and they will be checked against in the order they were added, if none of them match then excon will raise an `Excon::Errors::StubNotFound` error to let you know.

To remove a previously defined stub, or all stubs:

```ruby
Excon.unstub({})  # remove first/oldest stub matching {}
Excon.stubs.clear # remove all stubs
```

For example, if using RSpec for your test suite you can clear stubs after running each example:

```ruby
config.after(:each) do
  Excon.stubs.clear
end
```

You can also modify 'Excon.defaults` to set a stub for all requests, so for a test suite you might do this:

```ruby
# Mock by default and stub any request as success
config.before(:all) do
  Excon.defaults[:mock] = true
  Excon.stub({}, {:body => 'Fallback', :status => 200})
  # Add your own stubs here or in specific tests...
end
```

Instrumentation
---------------

Excon calls can be timed using the [ActiveSupport::Notifications](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) API.

```ruby
connection = Excon.new(
  'http://geemus.com',
  :instrumentor => ActiveSupport::Notifications
)
```

Excon will then instrument each request, retry, and error.  The corresponding events are named excon.request, excon.retry, and excon.error respectively.

```ruby
ActiveSupport::Notifications.subscribe(/excon/) do |*args|
  puts "Excon did stuff!"
end
```

If you prefer to label each event with something other than "excon," you may specify
an alternate name in the constructor:

```ruby
connection = Excon.new(
  'http://geemus.com',
  :instrumentor => ActiveSupport::Notifications,
  :instrumentor_name => 'my_app'
)
```

If you don't want to add activesupport to your application, simply define a class which implements the same #instrument method like so:

```ruby
class SimpleInstrumentor
  class << self
    attr_accessor :events

    def instrument(name, params = {}, &block)
      puts "#{name} just happened."
      yield if block_given?
    end
  end
end
```

The #instrument method will be called for each HTTP request, response, retry, and error.

For debugging purposes you can also use Excon::StandardInstrumentor to output all events to stderr. This can also be specified by setting the `EXCON_DEBUG` ENV var.

See [the documentation for ActiveSupport::Notifications](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) for more detail on using the subscription interface.  See excon's instrumentation_test.rb for more examples of instrumenting excon.

HTTPS/SSL Issues
----------------

By default excon will try to verify peer certificates when using SSL for HTTPS. Unfortunately on some operating systems the defaults will not work. This will likely manifest itself as something like `Excon::Errors::SocketError: SSL_connect returned=1 ...`

If you have the misfortune of running into this problem you have a couple options. If you have certificates but they aren't being auto-discovered, you can specify the path to your certificates:

```ruby
Excon.defaults[:ssl_ca_path] = '/path/to/certs'
```

Failing that, you can turn off peer verification (less secure):

```ruby
Excon.defaults[:ssl_verify_peer] = false
```

Either of these should allow you to work around the socket error and continue with your work.

Copyright
---------

(The MIT License)

Copyright (c) 2010-2013 [geemus (Wesley Beary)](http://github.com/geemus)

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
