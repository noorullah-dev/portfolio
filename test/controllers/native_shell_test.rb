require "test_helper"

# The Hotwire Native shell and the website are two separate documents: the
# shell ships Turbo and the mobile chrome, the website must keep full page
# loads. The inline `QM` bootstrap script that the print/toast helpers read is
# untyped JavaScript, so HTML-escaping its quotes would blank the global - this
# file locks both contracts down.
class NativeShellTest < ActionDispatch::IntegrationTest
  NATIVE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " \
              "AppleWebKit/605.1.15 Mobile/15E148 Hotwire Native/1.0"

  setup do
    @business = create_business(name: "Alpha Motors")
    @user = create_user(business: @business, role: "admin")
    sign_in_as(@user)
  end

  test "website shell keeps full page loads and the mobile tab bar" do
    get root_path

    assert_response :success
    body = response.body
    refute_includes body, "data-hotwire-native"
    assert_includes body, "qm-tabbar"      # bottom tabs for phones
    refute_includes body, "importmap"      # no Turbo on the website
  end

  test "native user agent switches to the native shell" do
    get root_path, headers: { "HTTP_USER_AGENT" => NATIVE_UA }

    assert_response :success
    body = response.body
    assert_includes body, "data-hotwire-native"
    assert_includes body, "qm-native-content"
    assert_includes body, "importmap"
    assert_includes body, "turbo"
    assert_includes body, "/assets/native-"
    refute_includes body, "qm-tabbar"      # native navigation owns the chrome
  end

  test "native flag param persists for the session and can be cleared" do
    get root_path, params: { native: 1 }
    assert_includes response.body, "data-hotwire-native"

    get customers_path
    assert_includes response.body, "data-hotwire-native", "flag should persist in the session"

    get root_path, params: { native: 0 }
    refute_includes response.body, "data-hotwire-native"
  end

  test "inline QM bootstrap script is valid JavaScript on both shells" do
    get root_path
    assert_qm_script_is_valid "website"

    get root_path, params: { native: 1 }
    assert_qm_script_is_valid "native shell"
  end

  test "titles come from document_title in both layouts" do
    get root_path
    assert_select "title", "Dashboard - QistManager"

    get customers_path
    assert_select "title", "Customers - QistManager"

    get more_menu_path, params: { native: 1 }
    assert_select "title", "More - QistManager"
  end

  test "path configuration is public json for both well-known routes" do
    reset! # Discard the login from setup so this checks anonymous access.
    [native_path_configuration_path, native_path_configuration_alias_path].each do |path|
      get path

      assert_response :success, "#{path} must be reachable before login"
      assert_equal "application/json", response.media_type

      payload = JSON.parse(response.body)
      assert_equal false, payload["settings"]["pull_to_refresh_enabled"]
      rules = payload["rules"]
      assert rules.any? { |rule| rule["patterns"].include?("/login") && rule["presentation"] == "replace" },
             "/login must replace the stack, never stack behind it"
      assert rules.any? { |rule| rule["patterns"] == ["/.*"] && rule["presentation"] == "push" },
             "every other screen must push onto the stack"
    end
  end

  private

  # A stray HTML entity inside <script> aborts the whole block (the browser
  # reports "Unexpected token '&'"), so the JSON quotes must survive raw.
  def assert_qm_script_is_valid(label)
    body = response.body
    assert_match(/var QM = \{\s*\n?\s*bizName: "/, body, "#{label}: QM.bizName must open with a raw quote")
    assert_includes body, 'currency: "', "#{label}: currency must open with a raw quote"
    refute_includes body, "&quot;", "#{label}: script content must not be HTML-escaped"
  end
end
