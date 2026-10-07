# The "More" screen: every section of the app in one menu.
#
# It is the fifth tab of the Hotwire Native shell (the native side has no
# sidebar) and the fallback menu for phones, so it is rendered from the same
# permission-filtered navigation tree as the sidebar - nobody ever sees a link
# they cannot open.
class MenusController < ApplicationController
  def index
    @shops = owner? ? Business.order(:name) : Business.none
  end
end
