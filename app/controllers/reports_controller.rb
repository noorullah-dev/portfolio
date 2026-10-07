class ReportsController < ApplicationController

  guard all: "reports.view"
  def index
    @from = params[:from].presence&.to_date || Date.current.beginning_of_month
    @to = params[:to].presence&.to_date || Date.current.end_of_month
    @report = params[:report].presence || "sales"

    @sales = Sale.shop.where(status: %w[completed delivered]).between(@from, @to)
    @purchases = Purchase.shop.completed.between(@from, @to)
    @expenses = Expense.shop.between(@from, @to)
    @payments = InstallmentPayment.shop.between(@from, @to)
    @supplier_payments = PurchasePayment.shop.between(@from, @to)

    @totals = {
      sales_amount: @sales.sum(:total_amount),
      sales_count: @sales.count,
      down_payments: @sales.sum(:down_payment),
      financed: @sales.sum { |sale| sale.financed_amount },
      cost_of_goods: @sales.sum(:cost_amount),
      purchases_amount: @purchases.sum(:total_amount),
      purchase_count: @purchases.count,
      expenses: @expenses.sum(:amount),
      collections: @payments.sum(:amount),
      supplier_payments: @supplier_payments.sum(:amount)
    }

    @gross_profit = @totals[:sales_amount] - @totals[:cost_of_goods] - @totals[:expenses]
    @daily = daily_table
    @accounts = ChartOfAccount.shop.active.order(:code).map do |account|
      [account, account.ledger_entries.where(entry_date: @from..@to)]
    end
    totals = Sale.shop.where(status: %w[completed delivered]).between(@from, @to)
                 .group(:customer_id)
                 .sum(:total_amount)
    @top_customers = totals.sort_by { |_, amount| -amount }.first(10).map do |customer_id, amount|
      [Customer.shop.find_by(id: customer_id), amount]
    end
  end

  private

  def daily_table
    days = (@from..@to).to_a
    sales = Sale.shop.where(status: %w[completed delivered]).between(@from, @to).group_by(&:sale_date)
    expenses = Expense.shop.between(@from, @to).group_by(&:expense_date)
    payments = InstallmentPayment.shop.between(@from, @to).group_by(&:payment_date)

    days.map do |day|
      {
        date: day,
        sales: sales.fetch(day, []).sum(&:total_amount),
        collections: payments.fetch(day, []).sum(&:amount),
        expenses: expenses.fetch(day, []).sum(&:amount)
      }
    end
  end
end