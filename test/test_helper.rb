ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # One worker: the suite is small, and forked workers hang in some sandboxes once tests exceed 50.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Creates and returns a persisted User with the given role. Facility roles default to a fresh
    # Facility unless one is given; rulebook roles never get one (see User's own validation).
    def create_user(role:, facility: nil, email: nil, dev_both_domains: false)
      facility ||= Facility.create!(name: "Test Facility #{SecureRandom.hex(3)} (fictional, synthetic)") if User::FACILITY_ROLES.include?(role)
      User.create!(email: email || "#{role}-#{SecureRandom.hex(4)}@example.test", password: "password123",
                   role: role, facility: facility, dev_both_domains: dev_both_domains)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
