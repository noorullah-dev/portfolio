require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "health endpoint is public and does not require a tenant session" do
    get "/up"
    assert_response :success
  end
end
