class DashboardController < ApplicationController

  guard index: "dashboard.view"
  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    @from = @month.beginning_of_month
    @to = @month.end_of_month

    @counts = {
      customers: Customer.shop.active.count,
      stock: StockUnit.shop.available.count,
      sales: Sale.shop.between(@from, @to).completed.count,
      receivables: Customer.shop.active.sum { |customer| customer.balance.to_d }
    }

    @recent_sales = Sale.shop.recent.includes(:customer, :stock_unit).limit(10)

    unpaid = InstallmentPlan.shop.where(sale_id: Sale.shop.active_sale_ids).where.not(status: "paid")
    @due_today = unpaid.where(due_date: Date.current).includes(sale: :customer)
    @overdue = unpaid.where(due_date: ...Date.current).includes(sale: :customer)

    @low_stock = StockUnit.shop.available.includes(:product, :variant).order(:sale_price).limit(10)

    @sales_series = daily_series(Sale.shop.completed.between(@from, @to), :sale_date, :total_amount, @from, @to)
    @expense_series = daily_series(Expense.shop.between(@from, @to), :expense_date, :amount, @from, @to)
    @collections_series = daily_series(
      InstallmentPayment.shop.between(@from, @to), :payment_date, :amount, @from, @to
    )
  end

  private

  def parse_month(value)
    return nil if value.blank?

    Date.parse("#{value}-01")
  rescue Date::Error
    nil
  end

  # Returns every calendar day in the range mapped to that day's total, so the
  # chart has no gaps. Avoids the groupdate gem.
  def daily_series(scope, date_column, amount_column, from, to)
    totals = scope.group(Arel.sql("date(#{date_column})"))
                  .pluck(Arel.sql("date(#{date_column})"), Arel.sql("SUM(#{amount_column})"))
                  .to_h { |day, sum| [day.to_s, sum.to_d] }

    (from..to).each_with_object({}) do |day, series|
      series[day.to_s] = totals.fetch(day.to_s, 0.to_d)
    end
  end
end