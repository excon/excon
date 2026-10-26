# frozen_string_literal: true

# Path to a file in the shared test fixtures (test/fixtures/data).
def data_path(*parts)
  File.join(File.expand_path('../fixtures/data', __dir__), *parts)
end
