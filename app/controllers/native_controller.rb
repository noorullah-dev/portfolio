# Static configuration for the Hotwire Native shell.
#
# The mobile app asks this endpoint how every route should be presented
# (pushed onto the stack, swapped in place, modal, pull-to-refresh on or off)
# before it renders anything. It carries no user data, so it is public: the
# client requests it on launch, often before a session exists.
class NativeController < ApplicationController
  skip_before_action :require_login

  def path_configuration
    render json: {
      settings: {
        # Nothing in this app is an infinite feed, so a refresh gesture would
        # only ever discard the user's place in a list.
        pull_to_refresh_enabled: false,
        push_style: "default"
      },
      rules: [
        # Signing in or out replaces whatever is on screen instead of stacking
        # another copy behind it.
        { patterns: ["/login", "/logout", "/access-denied"], presentation: "replace" },
        # Forms and long screens (reports, stock, collections) are ordinary
        # pushes; leaving them uses the shell's back gesture/button.
        { patterns: ["/.*"], presentation: "push" }
      ]
    }
  end
end
