# The installable-PWA surface: a web app manifest and a service worker.
# The browser fetches both before any session exists (and outside it), so they
# stay public: a manifest or a worker leaks nothing but static metadata, while
# a redirect-to-login would break installation entirely.
class PwaController < ApplicationController
  skip_before_action :require_login

  # Rails rejects JS-format GET responses to non-XHR requests so a hostile site
  # cannot embed them as <script>. A service worker registration is exactly
  # such a request (and never XHR), and the file holds no secrets - it only
  # registers install/activate/fetch listeners - so the check is skipped here.
  skip_after_action :verify_same_origin_request, only: :service_worker

  def manifest
  end

  # The worker template is dashed (pwa/service-worker.js), so render it by
  # path: template lookup is keyed on the action name.
  def service_worker
    render "pwa/service-worker"
  end
end
