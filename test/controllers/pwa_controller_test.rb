require "test_helper"

# The installable-PWA endpoints must work without a session - the browser
# fetches them before, during and after login - and the shell must advertise
# them so the browser can offer installation.
class PwaControllerTest < ActionDispatch::IntegrationTest
  test "manifest is public json with the app identity" do
    get pwa_manifest_path

    assert_response :success
    assert_equal "application/json", response.media_type

    payload = JSON.parse(response.body)
    assert_equal "QistManager", payload["name"]
    assert_equal "/", payload["scope"]
    assert_equal "/", payload["start_url"]
    assert_equal "standalone", payload["display"]
    assert payload["theme_color"].to_s.start_with?("#"), "theme color must be a hex value"
    assert payload["icons"].any? { |icon| icon["sizes"] == "512x512" }
  end

  test "service worker is public javascript that handles fetches" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.media_type, "javascript"
    assert_match "addEventListener", response.body
    assert_match "fetch", response.body
    refute_match(/csrf|authenticity/i, response.body)
  end

  test "sign-in and application shells link the manifest" do
    get login_url
    assert_response :success
    assert_select "link[rel=?][href=?]", "manifest", "/manifest"
    assert_select "meta[name=?][content=?]", "theme-color", "#6366f1"

    get root_url
    assert_response :redirect # signed out
    follow_redirect!
    assert_response :success
    assert_select "link[rel=?][href=?]", "manifest", "/manifest"
  end
end
