# Copied from my benchmark_hell repo: github.com/sgonyea/benchmark_hell

require 'benchmark'

iters = 100000

header_strings = ["some_key: some_value",
                  "another_key: another_value"]

puts 'header keys case sensativity'

Benchmark.bmbm do |x|

  x.report('case sensative (original)') do
    iters.times.each do
      headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key] = value
      end

      headers.has_key?('some_key') && headers['some_key'].casecmp('some_value')
      headers.has_key?('another_key') && headers['another_key'].casecmp('not_another_value')
      headers.has_key?('no_key')
    end
  end

  x.report('downcased keys') do
    iters.times.each do
      headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key.downcase] = value
      end

      if headers.has_key?('some_key') && headers['some_key'].casecmp('some_value') ; end
      if headers.has_key?('another_key') && headers['another_key'].casecmp('not_another_value') ; end
      if headers.has_key?('no_key') ; end
    end
  end

  x.report('two hashes') do
    iters.times.each do
      headers           = {}
      downcased_headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key] = value
        downcased_headers[key.downcase] = value
      end

      if downcased_headers.has_key?('some_key') && downcased_headers['some_key'].casecmp('some_value') ; end
      if downcased_headers.has_key?('another_key') && downcased_headers['another_key'].casecmp('not_another_value') ; end
      if downcased_headers.has_key?('no_key') ; end
    end
  end

  x.report('greped hash keys') do
    iters.times.each do
      headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key] = value
      end

      key = headers.keys.grep(/some_key/i)[0]
      if !key.nil? && headers[key].casecmp('somevalue') ; end

      key = headers.keys.grep(/another_key/i)[0]
      if !key.nil? && headers[key].casecmp('not_another_value') ; end

      key = headers.keys.grep(/no_key/i)[0]
      if !key.nil? ; end
    end
  end

  x.report('greped hash keys cached') do
    iters.times.each do
      headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key] = value
      end
      
      headers_keys = headers.keys

      key = headers_keys.grep(/some_key/i)[0]
      if !key.nil? && headers[key].casecmp('somevalue') ; end

      key = headers_keys.grep(/another_key/i)[0]
      if !key.nil? && headers[key].casecmp('not_another_value') ; end

      key = headers_keys.grep(/no_key/i)[0]
      if !key.nil? ; end
    end
  end

  x.report('save header details on read') do
    iters.times.each do
      headers = {}

      header_strings.each do |header_string|
        key, value = header_string.split(': ')
        headers[key] = value
        @satisfies_condition_1 = key.casecmp('some_key') && value.casecmp('somevalue')
        @satisfies_condition_2 = key.casecmp('another_key') && value.casecmp('not_another_value')
        @satisfies_condition_3 = key.casecmp('no_key')
      end

      if @satisfies_condition_1 ; end
      if @satisfies_condition_1 ; end
      if @satisfies_condition_3 ; end
    end
  end
end

=begin

$ rvm exec bash -c 'echo $RUBY_VERSION && ruby header_keys_case_sensitivity.rb'

ruby-1.8.7-p330
header keys case sensativity
Rehearsal ---------------------------------------------------------------
case sensative (original)     4.160000   0.000000   4.160000 (  4.175057)
downcased keys                4.720000   0.010000   4.730000 (  4.790463)
two hashes                    5.480000   0.000000   5.480000 (  5.492858)
greped hash keys              6.280000   0.010000   6.290000 (  6.293433)
greped hash keys cached       6.100000   0.010000   6.110000 (  6.115422)
save header details on read   5.480000   0.000000   5.480000 (  5.497879)
----------------------------------------------------- total: 32.250000sec

                                  user     system      total        real
case sensative (original)     4.180000   0.010000   4.190000 (  4.206339)
downcased keys                4.720000   0.000000   4.720000 (  4.770486)
two hashes                    5.450000   0.010000   5.460000 (  5.491951)
greped hash keys              6.270000   0.010000   6.280000 (  6.279552)
greped hash keys cached       6.090000   0.000000   6.090000 (  6.109134)
save header details on read   5.430000   0.010000   5.440000 (  5.438792)

ruby-1.9.2-p136
header keys case sensativity
Rehearsal ---------------------------------------------------------------
case sensative (original)     1.550000   0.000000   1.550000 (  1.572881)
downcased keys                1.790000   0.010000   1.800000 (  1.891695)
two hashes                    2.310000   0.010000   2.320000 (  2.320202)
greped hash keys              4.380000   0.010000   4.390000 (  4.406171)
greped hash keys cached       4.140000   0.000000   4.140000 (  4.174380)
save header details on read   2.410000   0.010000   2.420000 (  2.419557)
----------------------------------------------------- total: 16.620000sec

                                  user     system      total        real
case sensative (original)     1.550000   0.000000   1.550000 (  1.554437)
downcased keys                1.780000   0.000000   1.780000 (  1.785615)
two hashes                    2.320000   0.010000   2.330000 (  2.333576)
greped hash keys              4.360000   0.010000   4.370000 (  4.373437)
greped hash keys cached       4.140000   0.000000   4.140000 (  4.142913)
save header details on read   2.430000   0.010000   2.440000 (  2.530793)

=end
