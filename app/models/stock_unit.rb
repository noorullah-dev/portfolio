class StockUnit < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[available reserved sold returned].freeze

  belongs_to :product, optional: true
  belongs_to :variant, optional: true
  belongs_to :purchase, optional: true
  belongs_to :purchase_item, optional: true
  belongs_to :supplier, optional: true
  belongs_to :sale, optional: true

  has_many :sale_items, dependent: :nullify
  has_many :account_transfers, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }
  validates :engine_no, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :chassis_no, uniqueness: { case_sensitive: false }, allow_blank: true

  scope :available, -> { where(status: "available").includes(:product, :variant).order(date_added: :desc, id: :desc) }
  scope :sold, -> { where(status: "sold") }
  scope :low_stock, lambda { |threshold = nil|
    threshold ||= Current.business&.low_stock_alert.to_i || 0
    available.where(product_id: Product.shop.active.select(:id)).having("COUNT(*) <= ?", threshold)
  }
  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where(
      "stock_units.engine_no ILIKE :q OR stock_units.chassis_no ILIKE :q OR stock_units.reg_no ILIKE :q " \
      "OR stock_units.serial_no ILIKE :q OR stock_units.vehicle_model ILIKE :q",
      q: pattern
    )
  }

  def label
    [vehicle_model, engine_no.presence, chassis_no.presence].compact_blank.join(" / ")
  end

  def display_name
    label
  end

  def vehicle_model
    [product&.display_name, variant&.value].compact_blank.join(" ")
  end

  def to_s
    label.presence || "Stock ##{id}"
  end

  def available?
    status == "available"
  end

  def sold?
    status == "sold"
  end

  def sell!(sale)
    update!(status: "sold", sale_id: sale&.id, sold_on: Date.current, reg_no: sale&.reg_no.presence || reg_no)
  end

  def release!
    update!(status: "available", sale_id: nil, sold_on: nil)
  end

  def reserve!
    update!(status: "reserved")
  end

  def profit_if_sold_at(price)
    price.to_d - cost_price.to_d
  end
end