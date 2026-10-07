class AccountClosuresController < ApplicationController

  guard all: "installments.close"
  before_action :set_closure, only: %i[show destroy]

  def index
    @closures = AccountClosure.shop.includes(:customer, :sale, :created_by).order(closure_date: :desc, id: :desc)
    @closures = @closures.where(customer_id: params[:customer_id]) if params[:customer_id].present?

    @summary = {
      closed: AccountClosure.shop.count,
      settled: AccountClosure.shop.sum(:settled_amount),
      waived: AccountClosure.shop.sum(:waived_amount)
    }
  end

  def show; end

  def new
    @closure = AccountClosure.new(closure_date: Date.current, customer_id: params[:customer_id])
    load_collections
  end

  def create
    customer = Customer.shop.find(params.require(:account_closure).permit(:customer_id)[:customer_id])
    sale = sale_for(customer)

    remaining = params.require(:account_closure)[:remaining_balance].presence || customer.balance.to_s
    settled = params.require(:account_closure)[:settled_amount].presence || customer.paid_total.to_s
    waived = (remaining.to_d - settled.to_d).clamp(0..)

    @closure = AccountClosure.new(
      customer: customer,
      sale: sale,
      closure_date: params.require(:account_closure)[:closure_date].presence || Date.current,
      remaining_balance: remaining,
      settled_amount: settled,
      waived_amount: waived,
      reason: params.require(:account_closure)[:reason],
      status: "completed",
      created_by: current_user
    )

    if @closure.save
      if waived.positive?
        LedgerPosting.call(
          date: @closure.closure_date,
          source_type: "AccountClosure",
          source_id: @closure.id,
          source_no: "CL-#{@closure.id}",
          created_by: current_user,
          lines: [
            { account: Business.account(Business::RECEIVABLE_ACCOUNT_CODE), debit: waived,
              particulars: "Account closure waiver for #{customer.display_name}",
              party_type: "Customer", party_id: customer.id },
            { account: Business.account(Business::DEFAULT_EXPENSE_CODE), credit: waived,
              particulars: "Waiver written off for #{customer.display_name}" }
          ]
        )
      end

      redirect_to account_closures_path, notice: "Account closed for #{customer.display_name}."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @closure.destroy
    redirect_to account_closures_path, notice: "Closure record removed."
  end

  private

  def set_closure
    @closure = AccountClosure.shop.includes(:customer, :sale).find(params[:id])
  end

  def load_collections
    @customers = Customer.shop.active.order(:name)
  end

  def sale_for(customer)
    # sales have no stored balance column; the schedule decides what is open
    customer.active_sales.order(sale_date: :desc).first
  end
end