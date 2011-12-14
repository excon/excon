require 'active_support/notifications'

class SimpleInstrumentor
  class << self
    attr_accessor :events

    def instrument(name, params = {}, &block)
      @events ||= []
      @events << name
      yield if block_given?
    end
  end
end

Shindo.tests('Excon instrumentation') do

  after do
    ActiveSupport::Notifications.unsubscribe("excon")
    ActiveSupport::Notifications.unsubscribe("excon.request")
    ActiveSupport::Notifications.unsubscribe("excon.retry")
    ActiveSupport::Notifications.unsubscribe("excon.error")
    ActiveSupport::Notifications.unsubscribe("gug")
    Delorean.back_to_the_present
    Excon.stubs.clear
  end

  def subscribe(match)
    @events = []
    ActiveSupport::Notifications.subscribe(match) do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  def make_request(idempotent = false, params = {})
    connection = Excon.new(
      'http://127.0.0.1:9292',
      :instrumentor => ActiveSupport::Notifications,
      :mock         => true
    )
    if idempotent
      params[:idempotent] = :true
    end
    connection.get(params)
  end

  REQUEST_DELAY_SECONDS = 30
  def stub_success
    Excon.stub({:method => :get}) { |params|
      Delorean.jump REQUEST_DELAY_SECONDS
      {:body => params[:body], :headers => params[:headers], :status => 200}
    }
  end

  def stub_retries
    run_count = 0
    Excon.stub({:method => :get}) { |params|
      run_count += 1
      if run_count <= 3 # First 3 calls fail.
        raise Excon::Errors::SocketError.new(Exception.new "Mock Error")
      else
        {:body => params[:body], :headers => params[:headers], :status => 200}
      end
    }
  end

  def stub_failure
    Excon.stub({:method => :get}) { |params|
      raise Excon::Errors::SocketError.new(Exception.new "Mock Error")
    }
  end

  tests('basic notification').returns('excon.request') do
    subscribe(/excon/)
    stub_success
    make_request
    @events.first.name
  end

  tests('captures scheme, host, port, and path').returns([:host, :path, :port, :scheme]) do
    subscribe(/excon/)
    stub_success
    make_request
    [:host, :path, :port, :scheme].select {|k| @events.first.payload.has_key? k}
  end

  tests('params in request overwrite those in construcor').returns('cheezburger') do
    subscribe(/excon/)
    stub_success
    make_request(false, :host => 'cheezburger')
    @events.first.payload[:host]
  end

  tests('notify on retry').returns(3) do
    subscribe(/excon/)
    stub_retries
    make_request(true)
    @events.count{|e| e.name =~ /retry/}
  end

  tests('notify on error').returns(true) do
    subscribe(/excon/)
    stub_failure
    raises(Excon::Errors::SocketError) do
      make_request
    end

    @events.any?{|e| e.name =~ /error/}
  end

  tests('filtering').returns(['excon.request', 'excon.error']) do
    subscribe(/excon.request/)
    subscribe(/excon.error/)
    stub_failure
    raises(Excon::Errors::SocketError) do
      make_request(true)
    end

    @events.map(&:name)
  end

  tests('more filtering').returns(['excon.retry', 'excon.retry', 'excon.retry']) do
    subscribe(/excon.retry/)
    stub_failure
    raises(Excon::Errors::SocketError) do
      make_request(true)
    end

    @events.map(&:name)
  end

  tests('indicates duration').returns(true) do
    subscribe(/excon/)
    stub_success
    make_request
    (@events.first.duration/1000 - REQUEST_DELAY_SECONDS).abs < 1
  end

  tests('use our own instrumentor').returns(
      ['excon.request', 'excon.retry', 'excon.retry', 'excon.retry', 'excon.error']) do
    stub_failure
    connection = Excon.new(
      'http://127.0.0.1:9292',
      :instrumentor => SimpleInstrumentor,
      :mock         => true
    )
    raises(Excon::Errors::SocketError) do
      connection.get(:idempotent => true)
    end

    SimpleInstrumentor.events
  end

  tests('does not generate events when not provided').returns(0) do
    subscribe(/excon/)
    stub_success
    connection = Excon.new('http://127.0.0.1:9292', :mock => true)
    connection.get(:idempotent => true)
    @events.count
  end

  tests('allows setting the prefix').returns(
      ['gug.request', 'gug.retry', 'gug.retry','gug.retry', 'gug.error']) do
    subscribe(/gug/)
    stub_failure
    connection = Excon.new(
      'http://127.0.0.1:9292',
      :instrumentor       => ActiveSupport::Notifications,
      :instrumentor_name  => 'gug',
      :mock               => true
    )
    raises(Excon::Errors::SocketError) do
      connection.get(:idempotent => true)
    end
    @events.map(&:name)
  end

  tests('allows setting the prefix when not idempotent', 'foo').returns(
    ['gug.request', 'gug.error']) do
    subscribe(/gug/)
    stub_failure
    connection = Excon.new(
      'http://127.0.0.1:9292',
      :instrumentor       => ActiveSupport::Notifications,
      :instrumentor_name  => 'gug',
      :mock               => true
    )
    raises(Excon::Errors::SocketError) do
      connection.get()
    end
    @events.map(&:name)
  end

  with_rackup('basic.ru') do
    tests('works unmocked').returns('excon.request') do
      subscribe(/excon/)
      make_request(false, :mock => false)
      @events.first.name
    end
  end
end

