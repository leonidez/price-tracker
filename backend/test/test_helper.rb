ENV["RAILS_ENV"] ||= "test"
# A known token so auth tests are deterministic locally (CI sets its own value).
ENV["API_TOKEN"] ||= "test_token"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
