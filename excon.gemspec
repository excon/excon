Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'
  s.name              = 'excon'
  s.version           = '0.50.1'
  s.date              = '2016-07-07'
  s.rubyforge_project = 'excon'
  s.summary     = "speed, persistence, http(s)"
  s.description = "EXtended http(s) CONnections"
  s.authors  = ["dpiddy (Dan Peterson)", "geemus (Wesley Beary)", "nextmat (Matt Sanders)"]
  s.email    = 'geemus@gmail.com'
  s.homepage = 'https://github.com/excon/excon'
  s.license  = 'MIT'
  s.require_paths = %w[lib]
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md]

  s.add_development_dependency('activesupport', '>= 1.5.5')
  s.add_development_dependency('delorean', '>= 2.1.0')
  s.add_development_dependency('eventmachine', '>= 1.2.0.1')
  s.add_development_dependency('open4', '>= 1.3.4')
  s.add_development_dependency('rake', '>= 0.9.2.2')
  s.add_development_dependency('rdoc', '>= 3.9.5')
  s.add_development_dependency('shindo', '>= 0.3')
  s.add_development_dependency('sinatra', '>= 1.4.7')
  s.add_development_dependency('sinatra-contrib', '>= 1.4.7')
  s.add_development_dependency('json', '>= 1.5.5')

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    CONTRIBUTING.md
    CONTRIBUTORS.md
    Gemfile
    Gemfile.lock
    LICENSE.md
    README.md
    Rakefile
    benchmarks/class_vs_lambda.rb
    benchmarks/concat_vs_insert.rb
    benchmarks/concat_vs_interpolate.rb
    benchmarks/cr_lf.rb
    benchmarks/downcase-eq-eq_vs_casecmp.rb
    benchmarks/excon.rb
    benchmarks/excon_vs.rb
    benchmarks/for_vs_array_each.rb
    benchmarks/for_vs_hash_each.rb
    benchmarks/has_key-vs-lookup.rb
    benchmarks/headers_case_sensitivity.rb
    benchmarks/headers_split_vs_match.rb
    benchmarks/implicit_block-vs-explicit_block.rb
    benchmarks/merging.rb
    benchmarks/single_vs_double_quotes.rb
    benchmarks/string_ranged_index.rb
    benchmarks/strip_newline.rb
    benchmarks/vs_stdlib.rb
    changelog.txt
    data/cacert.pem
    excon.gemspec
    lib/excon.rb
    lib/excon/connection.rb
    lib/excon/constants.rb
    lib/excon/error.rb
    lib/excon/extensions/uri.rb
    lib/excon/headers.rb
    lib/excon/middlewares/base.rb
    lib/excon/middlewares/capture_cookies.rb
    lib/excon/middlewares/decompress.rb
    lib/excon/middlewares/escape_path.rb
    lib/excon/middlewares/expects.rb
    lib/excon/middlewares/idempotent.rb
    lib/excon/middlewares/instrumentor.rb
    lib/excon/middlewares/mock.rb
    lib/excon/middlewares/redirect_follower.rb
    lib/excon/middlewares/response_parser.rb
    lib/excon/pretty_printer.rb
    lib/excon/response.rb
    lib/excon/socket.rb
    lib/excon/ssl_socket.rb
    lib/excon/standard_instrumentor.rb
    lib/excon/unix_socket.rb
    lib/excon/utils.rb
    tests/authorization_header_tests.rb
    tests/bad_tests.rb
    tests/basic_tests.rb
    tests/complete_responses.rb
    tests/data/127.0.0.1.cert.crt
    tests/data/127.0.0.1.cert.key
    tests/data/excon.cert.crt
    tests/data/excon.cert.key
    tests/data/xs
    tests/error_tests.rb
    tests/header_tests.rb
    tests/middlewares/canned_response_tests.rb
    tests/middlewares/capture_cookies_tests.rb
    tests/middlewares/decompress_tests.rb
    tests/middlewares/escape_path_tests.rb
    tests/middlewares/idempotent_tests.rb
    tests/middlewares/instrumentation_tests.rb
    tests/middlewares/mock_tests.rb
    tests/middlewares/redirect_follower_tests.rb
    tests/pipeline_tests.rb
    tests/proxy_tests.rb
    tests/query_string_tests.rb
    tests/rackups/basic.rb
    tests/rackups/basic.ru
    tests/rackups/basic_auth.ru
    tests/rackups/deflater.ru
    tests/rackups/proxy.ru
    tests/rackups/query_string.ru
    tests/rackups/redirecting.ru
    tests/rackups/redirecting_with_cookie.ru
    tests/rackups/request_headers.ru
    tests/rackups/request_methods.ru
    tests/rackups/response_header.ru
    tests/rackups/ssl.ru
    tests/rackups/ssl_mismatched_cn.ru
    tests/rackups/ssl_verify_peer.ru
    tests/rackups/streaming.ru
    tests/rackups/thread_safety.ru
    tests/rackups/timeout.ru
    tests/rackups/webrick_patch.rb
    tests/request_headers_tests.rb
    tests/request_method_tests.rb
    tests/request_tests.rb
    tests/response_tests.rb
    tests/servers/bad.rb
    tests/servers/eof.rb
    tests/servers/error.rb
    tests/servers/good.rb
    tests/test_helper.rb
    tests/thread_safety_tests.rb
    tests/timeout_tests.rb
    tests/utils_tests.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^[spec|tests]\/.*_[spec|tests]\.rb/ }
end
