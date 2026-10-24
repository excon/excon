# frozen_string_literal: true

# Path to a file in the shared test fixtures (tests/data).
def data_path(*parts)
  File.join(File.expand_path('../../tests/data', __dir__), *parts)
end
