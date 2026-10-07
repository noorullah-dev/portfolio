class Purchase < ApplicationRecord
  include TenantScoped

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[completed cancelled].freeze

  belongs_to :supplier
  belongs_to :payment_mode, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :items, class_name: "PurchaseItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true
  has_many :payments, class_name: "PurchasePayment", dependent: :destroy
  has_many :stock_units, dependent: :nullify
  has_many :ledger_entries, as: :source, dependent: :nullify

  validates :purchase_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_amount, numericality: { greater_than: 0 }

  scope :recent, -> { order(purchase_date: :desc, id: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :between, ->(from, to) { where(purchase_date: from..to) }
  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    joins(:supplier)
      .where("purchases.purchase_no ILIKE :q OR purchases.invoice_no ILIKE :q OR suppliers.name ILIKE :q",
             q: pattern)
  }

  before_validation :apply_totals
  after_create :create_stock_units!
  after_create :update_variant_prices!
  after_create :post_purchase_entries!

  def document_number_kind
    :purchase
  end

  def display_name
    [purchase_no, supplier&.name].compact.join(" - ")
  end

  def to_s
    purchase_no
  end

  def cancelled?
    status == "cancelled"
  end

  def paid?
    paid_amount.to_d >= total_amount.to_d
  end

  def balance
    total_amount.to_d - paid_amount.to_d
  end

  def record_payment!(amount:, payment_date: Date.current, payment_mode: nil, reference: nil,
                       remarks: nil, created_by: nil)
    amount = amount.to_d
    raise ArgumentError, "Payment amount must be positive" unless amount.positive?

    transaction do
      payment = payments.create!(
        payment_date: payment_date,
        amount: amount,
        payment_mode: payment_mode,
        reference: reference,
        remarks: remarks,
        created_by: created_by
      )

      update!(paid_amount: paid_amount.to_d + amount)

      payable = Business.account(Business::PAYABLE_ACCOUNT_CODE)
      cash = CashBook.account_for(payment_mode)

      LedgerPosting.call(
        date: payment_date,
        source_type: "PurchasePayment",
        source_id: payment.id,
        source_no: purchase_no,
        created_by: created_by,
        lines: [
          { account: payable, debit: amount, particulars: "Payment to #{supplier.name}",
            party_type: "Supplier", party_id: supplier_id },
          { account: cash, credit: amount, particulars: "Payment to #{supplier.name}" }
        ]
      )

      CashBook.record(
        direction: "out",
        amount: amount,
        date: payment_date,
        payment_mode: payment_mode,
        particulars: "Supplier payment #{purchase_no} - #{supplier.name}",
        source_type: "PurchasePayment",
        source_id: payment.id,
        source_no: purchase_no,
        created_by: created_by
      )

      payment
    end
  end

  private

  def apply_totals
    line_items = items.to_a
    return if line_items.empty?

    line_items.each(&:compute_total)
    self.subtotal = line_items.sum { |item| item.total.to_d }
    self.total_amount = subtotal.to_d - discount.to_d
  end

  def create_stock_units!
    return if cancelled?

    items.each do |item|
      next unless item.create_stock_unit

      qty = [item.qty.to_d.round, 0].max
      qty.times do |index|
        stock_units.create!(
          product_id: item.product_id,
          variant_id: item.variant_id,
          purchase_item_id: item.id,
          supplier_id: supplier_id,
          engine_no: index.zero? ? item.engine_no : nil,
          chassis_no: index.zero? ? item.chassis_no : nil,
          cost_price: item.unit_price,
          sale_price: item.variant&.sale_price.to_d,
          status: "available",
          date_added: purchase_date,
          remarks: "Auto created from #{purchase_no}"
        )
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    # never let the save fail silently: surface the reason on the purchase form
    errors.add(:base, "Stock unit could not be created: #{e.record.errors.full_messages.to_sentence}")
    raise ActiveRecord::RecordInvalid, self
  end

  def update_variant_prices!
    items.each do |item|
      next if item.variant.nil?

      item.variant.update!(purchase_price: item.unit_price)
    end
  end

  def post_purchase_entries!
    return if total_amount.to_d <= 0

    payable = Business.account(Business::PAYABLE_ACCOUNT_CODE)
    inventory = Business.account(Business::INVENTORY_ACCOUNT_CODE)
    cash = CashBook.account_for(payment_mode)

    lines = [
      { account: inventory, debit: total_amount, particulars: "Stock purchase #{purchase_no}",
        party_type: "Supplier", party_id: supplier_id },
      { account: payable, credit: total_amount, particulars: "Stock purchase #{purchase_no}",
        party_type: "Supplier", party_id: supplier_id }
    ]

    if paid_amount.to_d.positive?
      lines << { account: cash, debit: paid_amount, particulars: "Advance paid to #{supplier.name}" }
      lines << { account: payable, credit: paid_amount, particulars: "Advance paid to #{supplier.name}",
                 party_type: "Supplier", party_id: supplier_id }
    end

    LedgerPosting.call(
      date: purchase_date,
      source_type: "Purchase",
      source_id: id,
      source_no: purchase_no,
      created_by: created_by,
      lines: lines
    )

    if paid_amount.to_d.positive?
      CashBook.record(
        direction: "out",
        amount: paid_amount,
        date: purchase_date,
        payment_mode: payment_mode,
        particulars: "Purchase payment #{purchase_no} - #{supplier.name}",
        source_type: "Purchase",
        source_id: id,
        source_no: purchase_no,
        created_by: created_by
      )
    end
  end
end