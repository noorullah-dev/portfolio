class PostDatedChequesController < ApplicationController

  guard index: "installments.view", new: "installments.collect", create: "installments.collect", update: "installments.collect", destroy: "installments.collect", deposit: "installments.collect", clear: "installments.collect", bounce: "installments.collect"
  before_action :set_cheque, only: %i[deposit clear bounce destroy]

  def index
    @cheques = PostDatedCheque.shop.includes(:customer, :sale, :created_by)
    @cheques = @cheques.where(status: params[:status]) if params[:status].present?
    @cheques = @cheques.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @cheques = @cheques.where("cheque_no ILIKE :q OR bank_name ILIKE :q OR customers.name ILIKE :q", q: term)
    end
    @cheques = @cheques.recent

    @totals = {
      pending: PostDatedCheque.shop.pending.sum(:amount),
      pending_count: PostDatedCheque.shop.pending.count,
      cleared: PostDatedCheque.shop.where(status: "cleared").sum(:amount),
      bounced: PostDatedCheque.shop.where(status: "bounced").count
    }
  end

  def new
    @cheque = PostDatedCheque.new(cheque_date: Date.current, customer_id: params[:customer_id])
    load_collections
  end

  def create
    @cheque = PostDatedCheque.new(cheque_params)
    @cheque.created_by = current_user

    if @cheque.save
      redirect_to post_dated_cheques_path, notice: "Cheque #{@cheque.cheque_no} recorded."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def deposit
    @cheque.deposit!
    redirect_to post_dated_cheques_path, notice: "Cheque #{@cheque.cheque_no} marked as deposited."
  end

  def clear
    @cheque.clear!
    redirect_to post_dated_cheques_path, notice: "Cheque #{@cheque.cheque_no} cleared."
  end

  def bounce
    @cheque.bounce!
    redirect_to post_dated_cheques_path, alert: "Cheque #{@cheque.cheque_no} marked as bounced."
  end

  def destroy
    @cheque.destroy
    redirect_to post_dated_cheques_path, notice: "Cheque removed."
  end

  private

  def set_cheque
    @cheque = PostDatedCheque.shop.find(params[:id])
  end

  def load_collections
    @customers = Customer.shop.active.order(:name)
    @sales = Sale.shop.includes(:customer).where(status: %w[completed delivered]).order(sale_date: :desc)
  end

  def cheque_params
    params.require(:post_dated_cheque).permit(:cheque_no, :bank_name, :customer_id, :sale_id, :account_no,
                                               :amount, :cheque_date, :covered_month, :remarks)
  end
end