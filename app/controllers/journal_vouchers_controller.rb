class JournalVouchersController < ApplicationController

  guard index: "journal.view", show: "journal.view", new: "journal.create", create: "journal.create", edit: "journal.create", update: "journal.create", destroy: "journal.create", post_voucher: "journal.post"
  before_action :set_voucher, only: %i[show edit update destroy post_voucher]
  before_action :authorize_posting!, only: :create

  def index
    @vouchers = JournalVoucher.shop.recent
    @vouchers = @vouchers.where(status: params[:status]) if params[:status].present?
    @vouchers = @vouchers.between(from_date, to_date) if params[:from].present? || params[:to].present?
    @vouchers = paginate(@vouchers, per_page: 25)
  end

  def show
    @ledger_entries = @voucher.ledger_entries.order(:id)
  end

  def new
    @voucher = JournalVoucher.new(voucher_date: Date.current, status: "draft")
    2.times { @voucher.lines.build }
    load_collections
  end

  def edit
    load_collections
  end

  def create
    @voucher = JournalVoucher.new(journal_voucher_params.merge(status: "draft"))

    if @voucher.save
      if params[:commit].to_s.downcase.include?("post") || params[:post_now]
        begin
          @voucher.post!(user: current_user)
        rescue LedgerPosting::UnbalancedError => e
          @voucher.errors.add(:base, e.message)
        end
      end
      redirect_to journal_voucher_path(@voucher), notice: "Journal voucher #{@voucher.voucher_no} saved."
    else
      @voucher.lines.build if @voucher.lines.empty?
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @voucher.posted?
      redirect_to journal_voucher_path(@voucher), alert: "A posted journal voucher cannot be edited."
      return
    end

    if @voucher.update(journal_voucher_params)
      redirect_to journal_voucher_path(@voucher), notice: "Journal voucher updated."
    else
      @voucher.lines.build if @voucher.lines.empty?
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @voucher.posted?
      redirect_to journal_voucher_path(@voucher), alert: "A posted journal voucher cannot be deleted."
    else
      @voucher.destroy
      redirect_to journal_vouchers_path, notice: "Journal voucher deleted."
    end
  end

  def post_voucher
    @voucher.post!(user: current_user)
    redirect_to journal_voucher_path(@voucher), notice: "Journal voucher #{@voucher.voucher_no} posted to the ledger."
  rescue ActiveRecord::RecordInvalid, LedgerPosting::UnbalancedError => e
    redirect_to journal_voucher_path(@voucher), alert: e.message
  end

  private

  def authorize_posting!
    authorize!("journal.post") if params[:commit].to_s.downcase.include?("post") || params[:post_now]
  end

  def set_voucher
    @voucher = JournalVoucher.shop.includes(:lines, :posted_by).find(params[:id])
  end

  def load_collections
    @accounts = ChartOfAccount.shop.active.order(:code).map { |a| ["#{a.code} #{a.name}", a.id] }
  end

  def from_date
    params[:from].presence&.to_date || 100.years.ago.to_date
  end

  def to_date
    params[:to].presence&.to_date || Date.current
  end

  def journal_voucher_params
    params.require(:journal_voucher).permit(:voucher_date, :description, :reference,
                                             lines_attributes: %i[id account_id debit credit remarks _destroy])
  end
end
