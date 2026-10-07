# Generates the straightforward ActiveRecord models from a compact spec.
# Models with real behaviour are hand written and listed in HAND_WRITTEN so they
# are never overwritten by this script.

require "fileutils"
require "active_support/core_ext/string/inflections"

ROOT = File.expand_path("..", __dir__)
MODELS = File.join(ROOT, "app", "models")

HAND_WRITTEN = %w[
  application_record business user customer sale purchase stock_unit
  installment_plan installment_payment ledger_entry chart_of_account voucher
  document_numbering ledger_posting cash_book
].freeze

def belongs_to_many_list(spec)
  Array(spec[:has_many]).map { |name, type, opts| [name, type, opts || {}] }
end

MODELS_SPEC = {
  "payment_mode" => {
    belongs_to: [],
    has_many: [],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').order(:sort_order, :name)"], ["cash", "where(is_cash: true)"]],
    extra: <<~RUBY,
      scope :cash_first, -> { order(Arel.sql("is_cash DESC"), :sort_order, :name) }

      def to_s
        name
      end
    RUBY
  },
  "expense_category" => {
    has_many: [["expenses", :has_many]],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').order(:name)"]],
  },
  "brand" => {
    has_many: [["products", :has_many], ["stock_units", :has_many]],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').order(:name)"], ["inactive", "where(status: 'inactive')"]],
  },
  "category" => {
    belongs_to: [],
    has_many: [["products", :has_many]],
    validates: ["name, presence: true",
                "category_type, inclusion: { in: %w[vehicle electronics general] }"],
    scopes: [["active", "where(status: 'active').order(:name)"]],
  },
  "product" => {
    belongs_to: [["brand", :belongs_to], ["category", :belongs_to]],
    has_many: [["variants", :has_many], ["stock_units", :has_many]],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').includes(:brand, :category).order(:name)"]],
    extra: <<~RUBY,
      def display_name
        [brand&.name, name].compact.join(" ")
      end

      def full_name
        [brand&.name, name, category&.name].compact.join(" - ")
      end
    RUBY
  },
  "variant" => {
    belongs_to: [["product", :belongs_to]],
    has_many: [["stock_units", :has_many]],
    validates: ["value, presence: true"],
    scopes: [["active", "where(status: 'active').includes(product: :brand).order(:value)"]],
    extra: <<~RUBY,
      def display_name
        [product&.display_name, value].compact.join(" / ")
      end

      def profit
        sale_price.to_d - purchase_price.to_d
      end
    RUBY
  },
  "supplier" => {
    has_many: [["purchases", :has_many], ["purchase_payments", :has_many]],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').order(:name)"]],
    extra: <<~RUBY,
      def total_purchases
        purchases.where.not(status: "cancelled").sum(:total_amount)
      end

      def total_paid
        purchases.where.not(status: "cancelled").sum(:paid_amount)
      end

      def balance
        total_purchases - total_paid
      end
    RUBY
  },
  "agent" => {
    has_many: [["customers", :has_many], ["agent_commissions", :has_many], ["sales", :has_many]],
    validates: ["name, presence: true"],
    scopes: [["active", "where(status: 'active').order(:name)"]],
    extra: <<~RUBY,
      def total_earned
        agent_commissions.sum(:earned_amount)
      end

      def total_paid
        agent_commissions.sum(:paid_amount)
      end

      def balance
        total_earned - total_paid
      end
    RUBY
  },
  "sale_item" => {
    belongs_to: [["sale", :belongs_to], ["product", :belongs_to], ["variant", :belongs_to], ["stock_unit", :belongs_to]],
    validates: [],
    extra: <<~RUBY,
      before_validation :compute_total

      def compute_total
        self.total = (qty.to_d * unit_price.to_d) - discount.to_d
      end
    RUBY
  },
  "installment_reminder" => {
    belongs_to: [["installment_plan", :belongs_to], ["sale", :belongs_to], ["customer", :belongs_to]],
    validates: [],
  },
  "quotation_plan" => {
    belongs_to: [["quotation", :belongs_to]],
    validates: [],
  },
  "purchase_item" => {
    belongs_to: [["purchase", :belongs_to], ["product", :belongs_to], ["variant", :belongs_to]],
    validates: [],
    extra: <<~RUBY,
      before_validation :compute_total

      def compute_total
        self.total = qty.to_d * unit_price.to_d
      end
    RUBY
  },
  "purchase_payment" => {
    belongs_to: [["purchase", :belongs_to], ["payment_mode", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
  },
  "journal_voucher" => {
    belongs_to: [["posted_by", :belongs_to, { class_name: "User" }]],
    has_many: [["lines", :has_many, { class_name: "JournalVoucherLine", dependent: :destroy }]],
    validates: [],
    extra: <<~RUBY,
      def total_debit
        lines.sum(:debit)
      end

      def total_credit
        lines.sum(:credit)
      end

      def balanced?
        (total_debit - total_credit).abs < 0.01
      end
    RUBY
  },
  "journal_voucher_line" => {
    belongs_to: [["journal_voucher", :belongs_to], ["account", :belongs_to, { class_name: "ChartOfAccount" }]],
    validates: [],
    extra: <<~RUBY,
      before_validation :one_sided

      def one_sided
        errors.add(:base, "Enter either a debit or a credit, not both") if debit.to_d.positive? && credit.to_d.positive?
        errors.add(:base, "Amount must be greater than zero") if debit.to_d <= 0 && credit.to_d <= 0
      end
    RUBY
  },
  "expense" => {
    belongs_to: [["category", :belongs_to, { class_name: "ExpenseCategory" }], ["payment_mode", :belongs_to], ["account", :belongs_to, { class_name: "ChartOfAccount" }], ["added_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      scope :recent, -> { order(expense_date: :desc, id: :desc) }
      scope :between, ->(from, to) { where(expense_date: from..to) }
    RUBY
  },
  "cash_book_entry" => {
    belongs_to: [["payment_mode", :belongs_to], ["account", :belongs_to, { class_name: "ChartOfAccount" }], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      scope :chronological, -> { order(entry_date: :desc, id: :desc) }
      scope :between, ->(from, to) { where(entry_date: from..to) }

      def cash_in?
        direction == "in"
      end

      def cash_out?
        direction == "out"
      end
    RUBY
  },
  "account_transfer" => {
    belongs_to: [["customer", :belongs_to], ["from_customer", :belongs_to, { class_name: "Customer" }], ["to_customer", :belongs_to, { class_name: "Customer" }], ["sale", :belongs_to], ["stock_unit", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    scope: [["recent", "order(transfer_date: :desc, id: :desc)"]],
  },
  "account_closure" => {
    belongs_to: [["customer", :belongs_to], ["sale", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    scope: [["recent", "order(closure_date: :desc, id: :desc)"]],
  },
  "post_dated_cheque" => {
    belongs_to: [["customer", :belongs_to], ["sale", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      scope :recent, -> { order(cheque_date: :desc, id: :desc) }
      scope :pending, -> { where(status: "pending") }

      def deposit!
        update!(status: "deposited", deposited_on: Date.current)
      end

      def bounce!
        update!(status: "bounced")
      end

      def clear!
        update!(status: "cleared")
      end
    RUBY
  },
  "credit_recovery" => {
    belongs_to: [["sale", :belongs_to], ["customer", :belongs_to], ["payment_mode", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    scope: [["recent", "order(recovery_date: :desc, id: :desc)"]],
  },
  "advance_booking_payment" => {
    belongs_to: [["advance_booking", :belongs_to], ["payment_mode", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
  },
  "advance_booking_plan" => {
    belongs_to: [["advance_booking", :belongs_to]],
    validates: [],
    extra: <<~RUBY,
      def balance
        amount.to_d - paid_amount.to_d
      end

      def overdue?
        status != "paid" && due_date < Date.current
      end
    RUBY
  },
  "registration_tracking" => {
    belongs_to: [["sale", :belongs_to], ["customer", :belongs_to], ["agent", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      def days_pending
        return 0 if letter_received?

        ((Date.current - (submitted_date || Date.current)).to_i).clamp(0..)
      end

      def overdue?
        expected_return_date.present? && expected_return_date < Date.current && !letter_received?
      end
    RUBY
  },
  "vehicle_document" => {
    belongs_to: [["sale", :belongs_to], ["customer", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      DOCUMENT_TYPES = %w[
        registration_card letter warranty_book insurance_challan
        engine_chassis_copy bill_of_sale other
      ].freeze

      scope :outstanding, -> { where(received: false) }
    RUBY
  },
  "agent_commission" => {
    belongs_to: [["agent", :belongs_to], ["sale", :belongs_to], ["customer", :belongs_to]],
    has_many: [["payments", :has_many, { class_name: "AgentCommissionPayment", dependent: :destroy }]],
    validates: [],
    extra: <<~RUBY,
      def balance
        earned_amount.to_d - paid_amount.to_d
      end
    RUBY
  },
  "agent_commission_payment" => {
    belongs_to: [["agent_commission", :belongs_to], ["payment_mode", :belongs_to], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
  },
  "ledger_entry" => {
    belongs_to: [["account", :belongs_to, { class_name: "ChartOfAccount" }], ["created_by", :belongs_to, { class_name: "User" }]],
    validates: [],
    extra: <<~RUBY,
      scope :chronological, -> { order(entry_date: :asc, id: :asc) }
      scope :between, ->(from, to) { where(entry_date: from..to) }
      scope :for_source, ->(type, id) { where(source_type: type, source_id: id) }

      def debit?
        debit.to_d.positive?
      end

      def credit?
        credit.to_d.positive?
      end

      def amount
        debit.to_d.positive? ? debit.to_d : credit.to_d
      end
    RUBY
  },
}.freeze

FileUtils.mkdir_p(MODELS)

def assoc_options(opts)
  return "" if opts.nil? || opts.empty?

  ", #{opts.map { |k, v| "#{k}: #{v.is_a?(Symbol) ? ":#{v}" : v.inspect}" }.join(", ")}"
end

MODELS_SPEC.each do |model, spec|
  next if HAND_WRITTEN.include?(model)

  lines = []
  lines << "class #{model.camelize} < ApplicationRecord"
  lines << ""

  Array(spec[:belongs_to]).each do |(name, type, opts)|
    next if type != :belongs_to

    lines << "  belongs_to :#{name}#{assoc_options(opts)}"
  end

  lines << ""

  Array(spec[:has_many]).each do |(name, type, opts)|
    next if type != :has_many

    lines << "  has_many :#{name}#{assoc_options(opts)}"
  end

  lines << "" unless Array(spec[:has_many]).empty?

  Array(spec[:validates]).each do |entry|
    entry = Array(entry).join(", ")
    entry = "#{entry}, presence: true" unless entry.include?(",")
    lines << "  validates :#{entry}"
  end

  lines << "" unless Array(spec[:validates]).empty?

  Array(spec[:scopes]).each do |(name, body)|
    lines << "  scope :#{name}, -> { #{body} }"
  end

  lines << "" unless Array(spec[:scopes]).empty?

  lines << spec[:extra].to_s.lines.map { |l| l.strip.empty? ? l : "  #{l}" }.join if spec[:extra]

  lines << "end"
  lines << ""

  File.write(File.join(MODELS, "#{model}.rb"), lines.join("\n"))
  puts "wrote #{model}.rb"
end

puts "done: #{MODELS_SPEC.size - (MODELS_SPEC.keys & HAND_WRITTEN).size} generated models"
