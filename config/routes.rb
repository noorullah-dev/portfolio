Rails.application.routes.draw do
  get "/up", to: "rails/health#show", as: :rails_health_check
  # Customer portal root; staff hitting it are bounced back to the app.
  get "/portal", to: "customer_portal#show", as: :customer_root
  get "/portal/statement", to: "customer_portal#statement", as: :customer_portal_statement
  get "/portal", to: "customer_portal#show", as: :customer_portal

  root "dashboard#index"

  # ------------------------------------------------------------------- PWA
  # Installable web app surface. Both endpoints are public: the browser fetches
  # them before any session exists, and a redirect to the login page would make
  # the app uninstallable.
  get "manifest", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker", to: "pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  # the captured design addresses the dashboard as /dashboard
  get "/dashboard", to: "dashboard#index", as: :dashboard

  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  get "/logout", to: "sessions#destroy", as: :logout
  post "/logout", to: "sessions#destroy"
  get "/access-denied", to: "access_denied#show", as: :access_denied
  get "/change-password", to: "passwords#edit", as: :change_password
  patch "/change-password", to: "passwords#update"

  # ------------------------------------------------------------ native app
  # The "More" menu: the whole navigation tree in one permission-filtered
  # screen. It is the native shell's fifth tab and the phone fallback menu.
  get "/more", to: "menus#index", as: :more_menu
  # How the native shell should present each route. Public by design.
  get "/.well-known/hotwire-native/path-configuration",
      to: "native#path_configuration", as: :native_path_configuration,
      defaults: { format: :json }
  get "/native/path-configuration",
      to: "native#path_configuration", as: :native_path_configuration_alias,
      defaults: { format: :json }

  # --------------------------------------------------- tenancy & access
  resources :branches
  resources :locations
  resources :audit_logs, only: %i[index show]
  get "/owner", to: "owner#index", as: :owner_businesses
  get "/owner/new", to: "owner#new", as: :new_owner_business
  post "/owner", to: "owner#create", as: :owner_businesses_create
  get "/owner/:id", to: "owner#show", as: :owner_business
  get "/owner/:id/edit", to: "owner#edit", as: :edit_owner_business
  patch "/owner/:id", to: "owner#update", as: :owner_business_update
  patch "/owner/:id/toggle_status", to: "owner#toggle_status", as: :toggle_status_owner_business
  post "/owner/:id/create_admin", to: "owner#create_admin", as: :create_admin_owner_business
  # The owner opens a shop to work inside it with full permissions, and closes
  # it to go back to the platform-wide view.
  post "/owner/:id/open", to: "owner#open", as: :open_owner_business
  delete "/owner/open", to: "owner#close", as: :close_owner_business

  # ------------------------------------------------------------- catalogue
  resources :brands
  resources :categories
  resources :products do
    resources :variants, only: %i[new create], shallow: true
  end
  # Top-level new/create for the standalone variants screen; product-scoped
  # new/create remain nested for the "Add Variant" button on a product.
  resources :variants, except: %i[show]

  # -------------------------------------------------------------- parties
  resources :suppliers do
    get :ledger, on: :member
  end
  resources :agents
  resources :agent_commissions, path: "agent-commissions"
  resources :customers do
    resources :sales, only: :index, shallow: true
  end

  # -------------------------------------------------------------- purchase
  resources :purchases do
    resources :purchase_payments, only: :create, path: "payments"
  end
  get "/purchase-list", to: "purchases#index", as: :purchase_list
  get "/purchase/new", to: "purchases#new", as: :new_purchase_form

  resources :stock_units, path: "stock", except: %i[new create] do
    member do
      patch :reserve
      patch :release
    end
  end
  get "/stock-list", to: "stock_units#index", as: :stock_list

  # ---------------------------------------------------------------- sales
  resources :sales do
    resources :installment_payments, only: :create, path: "payments"
    resource :registration_tracking, only: %i[new create show]
    resources :vehicle_documents, only: %i[create destroy]
    member do
      post :cancel
    end
  end
  get "/sales-list", to: "sales#index", as: :sales_list
  get "/sales/:sale_id/payment", to: "installment_payments#new", as: :new_sale_payment

  resources :quotations, except: %i[show edit update] do
    member { post :accept }
  end

  resources :vehicle_documents, path: "vehicle-documents", only: %i[index destroy]
  resources :credit_recoveries, path: "credit-recoveries", except: %i[show edit]

  # ----------------------------------------------------------- installments
  get "/installments/collection", to: "installment_collections#index", as: :installment_collections
  post "/installments/:id/remind", to: "installments#remind", as: :installment_reminder
  post "/installments/collection", to: "installment_collections#create"
  resources :post_dated_cheques, path: "pdc", except: %i[show edit] do
    member do
      patch :deposit
      patch :clear
      patch :bounce
    end
  end
  get "/installments/roznamcha", to: "roznamchas#index", as: :roznamcha
  get "/installments/short-tracker", to: "short_payments#index", as: :short_payments
  resources :account_transfers, path: "transfers" do
    member { patch :approve }
  end
  resources :account_closures, path: "closures", except: %i[edit]

  # -------------------------------------------------------------- bookings
  resources :advance_bookings, path: "bookings" do
    resources :advance_booking_payments, only: :create, path: "payments"
  end

  resources :registration_trackings, path: "registration-trackings", except: %i[show new create]

  # --------------------------------------------------------------- finance
  resources :chart_of_accounts, path: "accounts/chart"
  resources :journal_vouchers, path: "accounts/journal" do
    member { patch :post_voucher }
  end
  resources :vouchers, path: "accounts/vouchers", only: %i[index new create show] do
    collection do
      get :receipts
      get :payments
    end
  end
  get "/receipt-vouchers", to: "vouchers#receipts", as: :receipt_vouchers
  get "/payment-vouchers", to: "vouchers#payments", as: :payment_vouchers
  get "/vouchers/new-receipt", to: "vouchers#new", as: :new_receipt_voucher, defaults: { kind: "receipt" }
  get "/vouchers/new-payment", to: "vouchers#new", as: :new_payment_voucher, defaults: { kind: "payment" }
  resources :expenses
  get "/cash-book", to: "cash_book#index", as: :cash_book

  # ---------------------------------------------------------------- extras
  get "/qist-calculator", to: "qist_calculator#show", as: :qist_calculator
  post "/qist-calculator", to: "qist_calculator#show"
  get "/reports", to: "reports#index", as: :reports
  get "/settings/business", to: "business_settings#edit", as: :business_settings
  patch "/settings/business", to: "business_settings#update"
  resources :users, except: :show

  # Legacy aliases (underscored controller paths) kept so old links still resolve.
  get "/credit_recoveries", to: "credit_recoveries#index", as: :legacy_credit_recoveries
  get "/vehicle_documents", to: "vehicle_documents#index", as: :legacy_vehicle_documents
  get "/registration_trackings", to: "registration_trackings#index", as: :legacy_registration_trackings
end

