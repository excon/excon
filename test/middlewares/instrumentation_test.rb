# frozen_string_literal: true

require_relative '../test_helper'

# Records each #instrument call, and which events are open (inside their
# block) at any moment, so tests can check what excon itself instruments.
class RecordingInstrumentor
  Event = Struct.new(:name, :params, :block_given)

  attr_reader :events, :open_events

  def initialize
    @events = []
    @open_events = []
  end

  def instrument(name, params = {})
    @events << Event.new(name, params, block_given?)
    return unless block_given?

    @open_events.push(name)
    begin
      yield
    ensure
      @open_events.pop
    end
  end

  def names
    @events.map(&:name)
  end
end

module InstrumentationTestHelpers
  RETRIES_THEN_ERROR = %w[excon.request excon.retry excon.retry excon.retry excon.error].freeze

  def setup
    @instrumentor = RecordingInstrumentor.new
  end

  def teardown
    Excon.stubs.clear
  end

  def make_request(params = {})
    connection = Excon.new(
      'http://127.0.0.1:9292',
      instrumentor: @instrumentor,
      mock: true
    )
    connection.get(params)
  end

  def stub_success
    instrumentor = @instrumentor
    @open_during_request = nil
    Excon.stub({ method: :get }) do |params|
      @open_during_request = instrumentor.open_events.dup
      { body: params[:body], headers: params[:headers], status: 200 }
    end
  end

  def stub_retries
    run_count = 0
    Excon.stub({ method: :get }) do |params|
      run_count += 1
      raise Excon::Error::Socket, Exception.new('Mock Error') if run_count <= 3 # First 3 calls fail.

      { body: params[:body], headers: params[:headers], status: 200 }
    end
  end

  def stub_failure
    Excon.stub({ method: :get }) do |_params|
      raise Excon::Error::Socket, Exception.new('Mock Error')
    end
  end
end

class InstrumentationTest < Minitest::Test
  include InstrumentationTestHelpers

  def test_basic_notification
    stub_success
    make_request
    assert_equal %w[excon.request excon.response], @instrumentor.names
  end

  def test_captures_scheme_host_port_and_path
    stub_success
    make_request
    params = @instrumentor.events.first.params
    %i[host path port scheme].each { |key| assert params.key?(key), "expected request params to include #{key}" }
  end

  def test_params_in_request_overwrite_those_in_constructor
    stub_success
    make_request(path: '/cheezburger')
    assert_equal '/cheezburger', @instrumentor.events.first.params[:path]
  end

  def test_response_event_receives_the_response
    stub_success
    make_request
    assert_equal 200, @instrumentor.events.last.params[:status]
  end

  def test_request_runs_inside_the_request_block
    stub_success
    make_request
    assert_equal ['excon.request'], @open_during_request
  end

  def test_notify_on_retry
    stub_retries
    make_request(idempotent: true)
    assert_equal %w[excon.request excon.retry excon.retry excon.retry excon.response], @instrumentor.names
  end

  def test_notify_on_error
    stub_failure
    assert_raises(Excon::Error::Socket) { make_request }
    assert_equal %w[excon.request excon.error], @instrumentor.names
  end

  def test_error_event_receives_the_error
    stub_failure
    assert_raises(Excon::Error::Socket) { make_request }
    assert_instance_of Excon::Error::Socket, @instrumentor.events.last.params[:error]
  end

  def test_notify_on_retries_then_error
    stub_failure
    assert_raises(Excon::Error::Socket) { make_request(idempotent: true) }
    assert_equal RETRIES_THEN_ERROR, @instrumentor.names
  end

  def test_always_passes_a_block
    stub_success
    make_request(idempotent: true)
    assert_equal [true, true], @instrumentor.events.map(&:block_given)
  end

  def test_does_not_generate_events_when_not_provided
    stub_success
    Excon.new('http://127.0.0.1:9292', mock: true).get(idempotent: true)
    assert_empty @instrumentor.events
  end

  def test_allows_setting_the_prefix
    stub_failure
    assert_raises(Excon::Error::Socket) { make_request(idempotent: true, instrumentor_name: 'gug') }
    assert_equal %w[gug.request gug.retry gug.retry gug.retry gug.error], @instrumentor.names
  end

  def test_allows_setting_the_prefix_when_not_idempotent
    stub_failure
    assert_raises(Excon::Error::Socket) { make_request(instrumentor_name: 'gug') }
    assert_equal %w[gug.request gug.error], @instrumentor.names
  end
end

class StandardInstrumentorTest < Minitest::Test
  include InstrumentationTestHelpers

  def request_with_standard_instrumentor(url = 'http://127.0.0.1:9292', params = {})
    stub_failure
    connection = nil
    _, stderr = capture_io do
      assert_raises(Excon::Error::Socket) do
        connection = Excon.new(url, { instrumentor: Excon::StandardInstrumentor, mock: true }.merge(params))
        connection.get(idempotent: true)
      end
    end
    [connection, stderr]
  end

  def test_event_names
    _, stderr = request_with_standard_instrumentor
    names = stderr.split("\n").grep_v(/^  /).map { |line| line.split.first }
    assert_equal RETRIES_THEN_ERROR, names
  end

  def test_redacts_authorization_header
    auth_header = 'Basic dXNlcjpwYXNz'
    connection, stderr = request_with_standard_instrumentor(
      'http://user:pass@127.0.0.1:9292',
      headers: { 'Authorization' => auth_header }
    )
    refute_includes stderr, auth_header
    assert_equal auth_header, connection.data[:headers]['Authorization']
  end

  def test_redacts_password
    connection, stderr = request_with_standard_instrumentor('http://user:pass@127.0.0.1:9292')
    refute_includes stderr, '"pass"'
    assert_equal 'pass', connection.data[:password]
  end

  def test_redacts_proxy_password
    connection, stderr = request_with_standard_instrumentor(
      'http://user:pass@127.0.0.1:9292',
      proxy: { password: 'pass' }
    )
    refute_includes stderr, '"pass"'
    assert_equal 'pass', connection.data[:proxy][:password]
  end
end

class UnmockedInstrumentationTest < Minitest::Test
  include InstrumentationTestHelpers
  include TestServer

  test_server :webrick, 'basic.ru'

  def test_works_unmocked
    make_request(mock: false)
    assert_equal %w[excon.request excon.response], @instrumentor.names
  end
end
