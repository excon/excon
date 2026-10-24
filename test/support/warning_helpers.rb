# frozen_string_literal: true

# Runs the block with Ruby warnings and Excon's raise-on-warnings both off.
def silence_warnings
  orig_verbose = $VERBOSE
  $VERBOSE = nil
  Excon.set_raise_on_warnings!(false)
  yield
ensure
  $VERBOSE = orig_verbose
  Excon.set_raise_on_warnings!(true)
end
