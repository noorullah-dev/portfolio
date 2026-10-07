class VouchersController < ApplicationController

  guard all: "vouchers.view", new: "vouchers.create", create: "vouchers.create"
  before_action :set_voucher, only: %i[show]

  def index
    @vouchers = build_scope(Voucher.shop)
    @summary = {
      receipts: Voucher.shop.receipts.between(30.days.ago.to_date, Date.current).sum(:amount),
      payments: Voucher.shop.payments.between(30.days.ago.to_date, Date.current).sum(:amount)
    }
  end

  def receipts
    @vouchers = build_scope(Voucher.shop.receipts, force_kind: "receipt")
    @kind = "receipt"
    render :index
  end

  def payments
    @vouchers = build_scope(Voucher.shop.payments, force_kind: "payment")
    @kind = "payment"
    render :index
  end

  def show
    @ledger_entries = @voucher.ledger_entries.order(:id)
    @cash_entry = CashBookEntry.shop.where(source_type: "Voucher", source_id: @voucher.id).first
  end

  def new
    @voucher = Voucher.new(kind: params[:kind].presence || "receipt",
                           voucher_date: Date.current,
                           party_type: "Customer")
    load_collections
  end

  def create
    @voucher = Voucher.new(voucher_params)
    @voucher.created_by = current_user

    if @voucher.save
      redirect_to voucher_path(@voucher), notice: "#{@voucher.voucher_no} recorded."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_voucher
    @voucher = Voucher.shop.find(params[:id])
  end

  def build_scope(scope, force_kind: nil)
    kind = force_kind || params[:kind].presence
    scope = scope.where(kind: kind) if kind.present?
    scope = scope.where(party_type: params[:party_type]) if params[:party_type].present?
    if params[:from].present? || params[:to].present?
      from = params[:from].presence&.to_date || 100.years.ago.to_date
      to = params[:to].presence&.to_date || Date.current
      scope = scope.between(from, to)
    end
    scope = scope.where("voucher_no ILIKE :q OR party_name ILIKE :q OR reference ILIKE :q",
                        q: "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%") if params[:q].present?

    paginate(scope.includes(:payment_mode), per_page: 30)
  end

  def load_collections
    @payment_modes = PaymentMode.shop.cash_first
    @parties = { "Customer" => Customer.shop.active.order(:name).pluck(:name, :id),
                 "Supplier" => Supplier.shop.active.order(:name).pluck(:name, :id) }
    @accounts = ChartOfAccount.shop.active.order(:code).map { |a| ["#{a.code} #{a.name}", a.id] }
  end

  def voucher_params
    permitted = params.require(:voucher).permit(:kind, :voucher_date, :party_type, :party_id, :party_name,
                                                  :amount, :payment_mode_id, :reference, :remarks, :account_id)
    permitted[:party_name] ||= resolve_party_name(permitted)
    permitted
  end

  def resolve_party_name(permitted)
    return nil if permitted[:party_id].blank?

    case permitted[:party_type]
    when "Customer" then Customer.shop.find_by(id: permitted[:party_id])&.display_name
    when "Supplier" then Supplier.shop.find_by(id: permitted[:party_id])&.name
    end
  end
end