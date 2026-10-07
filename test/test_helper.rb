ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module TenantTestHelpers
  # Builders always pass the tenant explicitly - the application stamps tenant
  # columns from Current, and tests run outside a request.
  def create_business(name: "Alpha Motors", **attrs)
    Business.create!(name: name, status: "active", **attrs)
  end

  def create_branch(business:, name: "Main Branch", **attrs)
    Branch.create!(business: business, name: name, branch_type: "main", status: "active", **attrs)
  end

  def create_location(business:, name: "Workshop", **attrs)
    Location.create!(business: business, name: name, status: "active", **attrs)
  end

  def create_user(business: nil, role: "shop_admin", branch: nil, username: nil, **attrs)
    username ||= [role, business&.id, SecureRandom.hex(3)].compact.join("-")
    User.create!(
      username: username,
      full_name: attrs.delete(:full_name) || username.titleize,
      password: attrs.delete(:password) || "Passw0rd!123",
      role: role,
      status: "active",
      business: business,
      branch: branch,
      **attrs
    )
  end

  def as(user)
    Current.set_from(user)
    yield
  ensure
    Current.reset!
  end

  def as_platform_owner
    as(create_user(role: "owner")) { yield }
  end
end

class ActiveSupport::TestCase
  include TenantTestHelpers

  # No fixtures: every example builds exactly the records it needs.
  self.use_transactional_tests = true

  setup do
    Current.reset!
  end

  teardown do
    Current.reset!
  end
end

class ActionDispatch::IntegrationTest
  include TenantTestHelpers

  def sign_in_as(user, password: "Passw0rd!123")
    post login_path, params: { username: user.username, password: password }
    follow_redirect! if response.redirect?
    user
  end
end