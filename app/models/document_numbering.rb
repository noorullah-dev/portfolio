module DocumentNumbering
  extend ActiveSupport::Concern

  SEQUENCES = {
    sale: ["sales", :sale_no, "SALE"],
    purchase: ["purchases", :purchase_no, "PUR"],
    quotation: ["quotations", :quotation_no, "QUO"],
    receipt: ["vouchers", :voucher_no, "RCV"],
    payment: ["vouchers", :voucher_no, "PAY"],
    journal: ["journal_vouchers", :voucher_no, "JRN"],
    booking: ["advance_bookings", :booking_no, "BKG"],
    customer: ["customers", :account_no, "ACC"]
  }.freeze

  class << self
    def next_number(kind, year: Date.current.year, width: 4)
      table, column, prefix = SEQUENCES.fetch(kind)
      lock!("#{table}:#{column}")
      last = select_value(
        "SELECT MAX(#{column}) FROM #{table} WHERE #{column} LIKE #{quote("#{prefix}-#{year}-%")}"
      )
      sequence = last.to_s.split("-").last.to_i + 1
      format("%s-%d-%0#{width}d", prefix, year, sequence)
    end

    private

    def lock!(key)
      exec_query("SELECT pg_advisory_xact_lock(hashtext(#{quote(key)}))::text")
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end

    def exec_query(sql)
      ActiveRecord::Base.connection.internal_exec_query(sql)
    end

    def select_value(sql)
      ActiveRecord::Base.connection.select_value(sql)
    end
  end

  class_methods do
    def next_document_number(kind, **options)
      DocumentNumbering.next_number(kind, **options)
    end
  end

  included do
    before_validation :assign_document_number, on: :create
  end

  def assign_document_number
    return if document_number_column.nil?
    return if self[document_number_column].present?

    self[document_number_column] = DocumentNumbering.next_number(document_number_kind)
  end

  def document_number_kind
    raise NotImplementedError, "#{self.class} must define document_number_kind"
  end

  def document_number_column
    DocumentNumbering::SEQUENCES.fetch(document_number_kind)[1]
  end
end