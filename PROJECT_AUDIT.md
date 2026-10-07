# QistManager — Full Project Audit

**Project:** `/home/noor/qistmanager` · **Stack:** Ruby 3.4.5 · Rails 8.1.4 · PostgreSQL · Puma 8.0.2
**Frontend:** server-rendered ERB, Bootstrap 5 (vendored) + custom `site.css`, vanilla JS, no Hotwire/Turbo
**Audit date:** 2026-10-05 · **App URL:** `http://127.0.0.1:3000` · **DB:** `qistmanager_development`

---

## 1. Users, Roles and Access

### 1.1 User accounts (live database)

| # | Username | Full name | Role | Status | Business | Last login |
|---|----------|-----------|------|--------|----------|------------|
| 1 | `admin` | Administrator | admin | active | 1 | 2026-10-05 06:58 UTC |
| 2 | `manager` | Branch Manager | manager | active | 1 | never |
| 3 | `accounts` | Accounts Officer | accounts | active | 1 | never |

Demo passwords: `admin/admin123`, `manager/manager123`, `accounts/accounts123`.
No duplicate usernames, no orphaned users (all bound to Business 1).

### 1.2 Roles defined (`app/models/user.rb`)

`ROLES = admin, manager, accounts, staff` — each role gets a predicate (`admin?`, `manager?`, `accounts?`, `staff?`).

### 1.3 What each role can actually do today

| Capability | admin | manager | accounts | staff | Enforced by |
|---|---|---|---|---|---|
| Sign in / change own password | ✅ | ✅ | ✅ | ✅ | `require_login` |
| Dashboard, sales, purchases, customers, quotations | ✅ | ✅ | ✅ | ✅ | any authenticated user |
| Post receipts/payments, journal vouchers, cash book, reports | ✅ | ✅ | ✅ | ✅ | any authenticated user |
| Business settings (name, CNIC, NTN, currency, logo, fees) | ✅ | ❌ | ❌ | ❌ | `require_admin!` in `business_settings_controller.rb:4` |
| User management (create/edit/deactivate/reset password) | ✅ | ❌ | ❌ | ❌ | `require_admin!` in `users_controller.rb:2` |

**Gap A (high):** role-based authorisation is only applied to *Settings* and *Users*. Every other module is open to any signed-in user, so a `staff` or `accounts` user can post vouchers, cancel sales and change prices. `require_role!`, `can_manage_accounts?` and `can_view_reports?` exist in `application_controller.rb` / `user.rb` but **are never called**. Recommended: add `before_action` role gates per controller, e.g. accounts-only for vouchers/journal/cash-book/reports, no cancellation rights for `staff`, and hide non-permitted nav items.

### 1.4 Security controls that are in place

| Control | Status |
|---|---|
| Password hashing | `has_secure_password` (bcrypt 3.1.22) |
| Brute-force lockout | ✅ 5 failed logins → locked 15 minutes (`User::MAX_FAILED_LOGINS`, `LOCKOUT_MINUTES`) |
| Auto-unlock on expiry | ✅ `User#unlock!` on next attempt |
| Session hygiene | ✅ `reset_session` on sign-in and sign-out |
| CSRF | ✅ on every form (`protect_from_forgery` default) |
| Open-redirect guard | ✅ `redirect_back_or` falls back to a safe path |
| Password change | Requires current password; sets `must_change_password = false` |
| Username format | Restricted to letters, numbers, dot, dash, underscore; normalised to lowercase |

**Gap B (medium):** `must_change_password` is stored but never *forced* — no redirect loop forces a change after an admin reset. **Gap C (low):** `has_secure_password` has no length/complexity rule, and password reset (email) does not exist. **Gap D (low):** no audit trail of *who* changed prices/statuses (`created_by` exists on sales and ledger lines but is not exposed in a log screen).

---

## 2. Feature Inventory (what each feature does)

Menu structure lives in `app/helpers/application_helper.rb:5` (`NAV_SECTIONS`). 123 routes in `config/routes.rb`.

### 2.1 MAIN
| Feature | Route | What it does |
|---|---|---|
| Dashboard | `/`, `/dashboard` | KPI cards (sales, expenses, collections, receivables, cash), recent sales with balance columns, due-customer list with months/due, quick-action buttons |

### 2.2 Products (catalogue)
| Feature | Route | What it does |
|---|---|---|
| Brands | `/brands` | Vehicle/make brands, used by products and stock |
| Categories | `/categories` | Grouping (e.g. Vehicle) for products |
| Products | `/products` | Bike/car/other catalogue with brand, model, purchase & sale price, stock flags |
| Variants | `/variants` | Colour/engine/trim variants per product (nested creation from a product) |

### 2.3 TRANSACTIONS — Purchase
| Feature | Route | What it does |
|---|---|---|
| Suppliers | `/suppliers` | Supplier master with totals paid / owed / opening balance |
| Supplier ledger | `/suppliers/:id/ledger` | Date-wise debit (paid) vs credit (owed) statement with running balance and totals |
| New Purchase | `/purchases/new` | Purchase with multiple line items, auto stock-unit creation, supplier payment |
| Purchase payments | `/purchases/:id/payments` | Records supplier payments; updates `paid_amount` and supplier ledger |
| Purchase List | `/purchases`, `/purchase-list` | Filterable list with paid/balance columns |
| Stock List | `/stock`, `/stock-list` | Vehicle-level stock: brand/model, engine, chassis, challan, reg, biometric, serial, warranty, status; reserve/release actions |

### 2.4 TRANSACTIONS — Sales
| Feature | Route | What it does |
|---|---|---|
| New Sale | `/sales/new` | Cash or credit sale, line items, down payment, auto installment plan generation, stock link, agent/salesman attribution |
| Sales List | `/sales`, `/sales-list` | Sale register with customer, type, total, financed, paid, overdue, status, cancel action |
| Sale cancellation | `POST /sales/:id/cancel` | Marks cancelled and reverses accounting effects |
| Installment payment | `/sales/:id/payments` | Records collection, updates plan status, cash book and ledger |
| Quotation | `/quotations` | Quotation with plan rows; `accept` converts to a sale and reserves stock |
| Qist Calculator | `/qist-calculator` | Flat-rate and reducing-balance monthly instalment schedule with down payment |
| Vehicle Documents | `/vehicle-documents` | Tracks Letter and Warranty Book per sale (received / not tracked) |
| Advance Booking | `/bookings` | Booking with its own plan schedule and payments |
| Credit Recovery | `/credit-recoveries` | Per-sale recovery-plan table with agreed dates, recovery history and mode/remarks |
| Customers | `/customers` | Customer master, ledger summary, short-plan risk badges |

### 2.5 INSTALLMENTS
| Feature | Route | What it does |
|---|---|---|
| Collection | `/installments/collection` | Daily collection desk: per-plan collection, summary, reminders |
| PDC Cheques | `/pdc` | Post-dated cheque register with deposit / clear / bounce lifecycle |
| Roznamcha | `/installments/roznamcha` | Printable payment schedule per customer |
| Short Tracker | `/installments/short-tracker` | Customers whose paid amount is below plan, with per-month breakdown |
| Transfer | `/transfers` | Move remaining instalments between accounts, with approve step |
| Closure | `/closures` | Close a financed account once fully recovered |
| Agents | `/agents` | Agent master with sales and commission totals |
| Commissions | `/agent-commissions` | Commission per sale, payment recording |
| Registration Tracking | `/registration-trackings` | Document/registration checklist per vehicle sale |

### 2.6 FINANCE
| Feature | Route | What it does |
|---|---|---|
| Chart of Accounts | `/accounts/chart` | 21 seeded accounts (Cash, Bank, Receivable, Stock, Supplier advances, Payable, income, expense, Owner Drawings) |
| Journal Voucher | `/accounts/journal` | Double-entry voucher with line editor, balance validation, draft/post |
| Receipt Voucher | `/accounts/vouchers/receipts`, `/vouchers/new-receipt` | Money-in voucher; posts to ledger + cash book |
| Payment Voucher | `/accounts/vouchers/payments`, `/vouchers/new-payment` | Money-out voucher; posts to ledger + cash book |
| Expenses | `/expenses` | Categorised expenses (10 categories) posting to the ledger |
| Cash Book | `/cash-book` | Date-range cash in/out with running balance, payment-mode filter and per-mode totals |
| Reports | `/reports` | Date-range P&L: sales, purchases, expenses, collections, COGS, gross profit, daily table, account-wise ledger, top-10 customers |
| Business Settings | `/settings/business` | Name, type, phone, email, address, city, CNIC, NTN, currency, footer text, default instalment day, late-fee type/amount, low-stock alert, allow-negative-stock, logo upload |
| Users | `/users` | Create/edit users, roles, activate/deactivate, force password change |

### 2.7 Extras
Qist Calculator (see above) · Business logo upload (`public/uploads`) · printable invoice/receipt headers · document auto-numbering per type/year (`DocumentNumbering` concern).

---

## 3. Accounting Integrity (verified in the live database)

| Check | Result |
|---|---|
| Ledger debits vs credits | 29,490,087 = 29,490,087 → **balanced (diff 0)** |
| Unbalanced-posting guard | ✅ `LedgerPosting` raises `UnbalancedError` if debit ≠ credit (≥ 0.01) |
| Cash book | in 3,761,000 · out 20,087 · running balance verified |
| Sales vs collections | sales 22,500,000 · financed 20,000,000 · down 2,500,000 · collected 450,000 |
| Installment plans | 60 generated, 60 open, **3 overdue**, overdue amount **849,999.99** |
| Journal vouchers | 1 posted, 0 draft (post enforced) |
| Referential safety | `restrict_with_error` on installment payments, `nullify`/`destroy` chosen per association, friendly dependent-record errors |

---

## 4. Data Coverage in the Demo Database

| Entity | Rows | Entity | Rows |
|---|---|---|---|
| Business | 1 | Sale | 5 |
| Chart of Accounts | 21 | SaleItem | **0** ⚠ |
| Brand | 17 | InstallmentPlan | 60 |
| Category | 42 | InstallmentPayment | 3 |
| Product | 6 | Quotation | 1 |
| Variant | 8 | AdvanceBooking / Plan / Payment | 3 / 36 / 0 |
| StockUnit | 6 (5 sold, 1 available) | Agent / AgentCommission | 4 / 5 |
| Supplier | 6 | JournalVoucher / Line / LedgerEntry | 1 / 2 / 46 |
| PaymentMode | 6 | CashBookEntry | 25 |
| ExpenseCategory | 10 | Expense | 1 |
| Customer | 5 | Purchase / PurchaseItem / PurchasePayment | **0 / 0 / 0** ⚠ |
| User | 3 | PDC / Transfers / Closures / VehicleDocs / RegistrationTracking / CreditRecovery / Reminders | **all 0** ⚠ |

**Gap E (medium):** the demo dataset has no purchases, no PDC/transfer/closure/vehicle-document/registration/recovery/reminder rows and **no sale line items**, so those screens look empty on a fresh install even though the code paths are smoke-tested. Recommended: extend `db/seeds.rb` with one purchase + payment, one sale with 1–2 items, one PDC, one vehicle document and one registration record.

---

## 5. Design, Theme and Frontend Audit

| Item | Result |
|---|---|
| Captured-design parity | 27 of 37 mapped screens contain every captured table column; remaining differences are inner form-line tables (kept as responsive cards) and the dashboard due list |
| Every page reachable | 72 pages × {light, dark} × {1440px, 390px} → **0 HTTP failures, 0 horizontal overflow** |
| Colour theme | Light / Dark / **Auto (follows OS, live)** via topbar palette button |
| Accent colours | 9 palettes (indigo, blue, sky, teal, emerald, amber, rose, violet, slate) |
| Density | Comfortable / Compact (row padding 11.2px ↔ 6.4px) |
| Persistence | `localStorage` (`qm.theme`, `qm.accent`, `qm.density`), applied **before first paint** — no flash |
| Accessibility | WCAG AA contrast audit: **0 failures / 20 pages in light, 0 / 20 in dark**; accent-aware focus ring; status pills fixed (was 1.6:1 white-on-amber) |
| Print | Always light, sidebar/topbar hidden, verified via print media emulation |
| No-JS requirement | All business flows work with JavaScript disabled; only the theme switcher needs JS |
| Responsive nav | Fixed sidebar, collapsible groups (state kept in session), off-canvas drawer with overlay on mobile |

---

## 6. Test & Verification Coverage

| Suite | Command | Result |
|---|---|---|
| Form/actions | `bin/rails runner -e test script/smoke_forms.rb` | ✅ 79 pass / 0 fail / 0 skip |
| Finance & cancellations | `bin/rails runner script/smoke_finance.rb` | ✅ passed |
| All screens | `ruby script/smoke_screens.rb` | ✅ ALL SCREENS OK (54) |
| Autoload | `bin/rails zeitwerk:check` | ✅ All is good! |
| Theme/contrast/sweeps | `tmp/audit/*.py` | ✅ 0 failures |

**Gap F (high):** there is **no `test/` or `spec/` directory** — zero unit/model/request tests. Everything is verified by custom scripts. Recommended: add Minitest coverage for `InstallmentPlanner`, `LedgerPosting`, `Sale` cancellation, `User.authenticate` lockout, and request specs for the role gates.

**Gap G (medium):** Active Storage variants (image resizing) cannot run in this environment — installed libvips/ruby-vips are incompatible. Original uploads and local serving work; production should pin `image_processing` + a matching libvips.

---

## 7. Risk Register (ordered)

| # | Severity | Finding | Where |
|---|---|---|---|
| A | High | No role-based access control outside Settings/Users; unused `require_role!` / `can_view_reports?` | `app/controllers/application_controller.rb:34-45`, `app/models/user.rb:63-68` |
| F | High | No automated test suite (`test/` absent) | project root |
| E | Medium | Demo data missing purchases, sale items, PDC, vehicle docs, registration, recoveries → empty screens on fresh install | `db/seeds.rb` |
| G | Medium | Image variants blocked by libvips mismatch | environment |
| B | Medium | `must_change_password` never enforced | `passwords_controller.rb`, `users_controller.rb:39` |
| H | Medium | Demo passwords are well-known (`admin123`) and shipped in seeds | `db/seeds.rb` |
| I | Low | No audit log screen for price/status changes | — |
| C | Low | No password complexity rule | `app/models/user.rb` |
| J | Low | `Rails.application.config.dependencies` unused; `bundler-audit`/`debug` present but no CI | `Gemfile` |
| K | Low | Installment reminders are manual only (no `ApplicationJob`/mailer jobs in use) | `app/jobs`, `installments_controller#remind` |

---

## 8. Implementation Follow-up (supersedes sections 1-7 where they disagree)

Sections 1-7 describe the state of the codebase **before** the tenancy, RBAC, audit-trail
and theme work. This section is the current, verified state.

### 8.1 Multi-tenancy

- `Business` is the tenant root; every business has a slug and its own branches, locations,
  users, reference data and documents.
- `Current` (`app/models/current.rb`) carries `user`, `business`, `branch`, `location` and
  `cross_tenant?` for the request, set in `ApplicationController#with_current_context`.
- `TenantScoped` (`app/models/concerns/tenant_scoped.rb`) supplies three explicit scopes:
  `.shop` (business), `.shop_wide` (business + all branches), `.platform` (all businesses,
  owner only). **There is no global `default_scope`** - every query must state its tenant
  intent, which is what the static query audit checks for.
- A static audit of hand-written `find_by`/`where`/`find_or_create_by`/`exists?`/association
  calls found 138 candidate sites; 107 were unscoped tenant reads and were corrected across
  29 controllers/models (dashboards, reports, index screens, vouchers, finance dropdowns,
  reference data, customers, stock, collections).
- Intentionally global reads kept global: authentication, the owner console, platform audit
  logs, and vehicle engine/chassis identity lookups (globally unique by design).
- `Business.account(code)` resolves system accounts through `Current.business_id` while
  still allowing cross-tenant owners; `CashBook.account_for` uses it, so cash/bank ledger
  lines cannot pick up another shop's account.

### 8.2 Roles and permissions

`User::ROLES` is now `owner, shop_admin, branch_manager, accountant, cashier,
recovery_officer, customer`. Permissions are declared per role in
`app/models/role_permission.rb` (`can?`), enforced by `require_permission!` in
`ApplicationController`, and the navigation and buttons are filtered by the same rules
(`permitted_path?`, `permitted_destination?`, `permitted_form_with`, `permitted_button_to`).

| Scope | Role | Reach |
|---|---|---|
| Platform | `owner` | read-only supervision of all businesses; writes only via owner/password/session flows |
| Business | `shop_admin` | whole business, all branches |
| Branch | `branch_manager` | one branch (no user administration) |
| Branch | `accountant` | one branch, finance/vouchers/reports |
| Branch | `cashier` | one branch, sales/collections |
| Assigned | `recovery_officer` | only the locations assigned to them |
| Self | `customer` | own customer portal (`/portal`, `/portal/statement`) |

Role names in the UI are humanised (`shop_admin` -> "Shop Admin"); legacy role aliases
(`admin`, `manager`, `accounts`, `staff`) still resolve to their canonical roles.

### 8.3 Audit trail (closes Gap D / risk I)

- `AuditLog` records actor, role, business, branch, action, record type/id and a
  `detail` payload (previously named `changes`).
- Written from the controllers that mutate money, status or identity, inside the same
  transaction as the change.
- Screen: `/audit_logs` for a business, platform-wide for `owner`, read-only.
- Verified over HTTP: `GET /audit_logs` is 200 for `owner` and `shop_admin`, and a POST to
  create a customer is recorded as `customers.create`.

### 8.4 Demo data (closes Gap E)

`db/seeds.rb` is tenant-aware and idempotent:

- platform owner, then per business: slug, branches ("Main Branch" + annex), locations,
  `shop_admin` plus branch staff, business reference data, catalogue and demo activity.
- All writes run inside `Current.set_from(shop_admin)` so tenant stamping matches the app.
- Identifier collisions across businesses are handled (chart codes are per business; vehicle
  identity numbers stay globally unique).
- `SEED_SECOND_SHOP=1 bin/rails db:seed` adds a second business (`second-shop`) to prove
  isolation; a plain `bin/rails db:seed` only fills the first business.
- Development database currently holds both businesses and the roles listed in section 8.2.

### 8.5 Tests and smoke suites

| Suite | Result |
|---|---|
| `bin/rails test test/` | 99 runs, 828 assertions, 0 failures, 0 errors, 0 skips |
| `script/smoke_forms.rb` | 91 pass, 0 fail, 2 expected owner-console skips |
| `script/smoke_finance.rb` | all checks pass (runs inside the admin tenant context) |
| `QM_BASE=http://127.0.0.1:3000 bin/rails runner script/smoke_screens.rb` | all screens OK |

New coverage: `test/controllers/cross_tenant_screens_test.rb` (dashboards, reports, index
screens, finance dropdowns, ledger accounts and owner cross-tenant reads),
`test/controllers/authorization_test.rb` (role gates, sign-in screen rendering), plus the
planner, ledger, cancellation, lockout and audit tests.

### 8.6a Responsive filters and action icons

- One filter contract, `.qm-toolbar`, shared by every list screen (including the generic
  `shared/index` scaffold and `search_form`). Filters are a single full-width column on
  phones (each control and button 100% wide, 38px+ tall), wrap into rows on tablets and
  stay inline on desktop. Fixed inline `min-width` values were replaced by flexible
  classes (`.qm-search`).
- Measured over all 72 authenticated screens at 390/768/1280: no horizontal overflow, no
  control outside its form, no undersized input on phones.
- Every text-only edit/delete action now carries an icon (`bi-pencil`, `bi-trash`) next to
  its label and a `title`, and the owner console's suspend/reactivate buttons got
  `bi-slash-circle`/`bi-play-circle`. Icon-only row actions were left as they were.

### 8.6 Frontend, theme and accessibility (closes the section 5 findings)

- Tokens live at the top of `app/assets/stylesheets/site.css`; both themes are driven from
  the same variables, and the switcher persists in `localStorage` with `auto` following
  `prefers-color-scheme`.
- Light/dark contrast and surface-leak audit over 25 admin pages, 7 owner pages and both
  portal pages: **0 low-contrast findings, 0 dark-mode surface leaks.**
- Mobile (390px) and tablet (768px) sweeps over all of those pages: **no horizontal
  overflow.** The topbar shrinks (ellipsised business name, hidden bell and user-pill name on
  phones) instead of pushing the viewport wider.
- Print styles still drop the sidebar and topbar and force a white background.
- Layout contract preserved: `.qm-wrapper`, `#sidebar.qm-sidebar`, `#mainContent.qm-main`,
  `.qm-topbar`, `.qm-page-content`, `#divMain`.
- Fixed while auditing: `permitted_form_with` passed an explicit `nil` model to
  `form_with`, which turned the sign-in page into a 500; regression test added.

### 8.7 Still open

| # | Severity | Finding | Where |
|---|---|---|---|
| L1 | Medium | `branch_manager` still lists user administration permissions; decide whether branch managers may manage branch users | `app/models/role_permission.rb` |
| L9 | Medium | An owner who opens a tenant screen (for example `/sales`) sees the first business only, because `Business.current` falls back to the lowest id; the owner console is the intended supervision surface | `app/models/business.rb`, `app/helpers/application_helper.rb#business` |
| L2 | Medium | Supplier ledger opening balances and payment reconciliation not yet reconciled | finance screens |
| L3 | Low | Audit-write failures are swallowed (`ActiveRecord::ActiveRecordError`); consider logging | audit concern |
| L4 | Low | Active Storage image variants blocked by a libvips/ruby-vips mismatch (originals upload fine) | environment |
| L5 | Low | Demo passwords are well known (`admin123`) - fine for development only | `db/seeds.rb` |
| L6 | Low | No password complexity/length rule | `app/models/user.rb` |
| L7 | Low | Installment reminders are still manual; no mailer/job infrastructure | `app/jobs` |
| L8 | Low | No CI, no `bundler-audit` run | `Gemfile` |

## 9. Recommended Next Steps (current)

1. L1: settle branch-manager user administration, then re-run the authorization suite.
2. L2: reconcile supplier opening balances and payments against the ledger.
3. L3: log swallowed audit-write failures instead of ignoring them.
4. L6/L7: add a password length rule and mailer-backed installment reminders.
5. Add CI (test suite + `bundler-audit`) once L1-L3 are closed.
6. Schedule reminders with `ApplicationJob` + a nightly rake task, and enable `config.active_record.dump_schema_after_migration = false` discipline.