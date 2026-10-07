class ShortPaymentsController < ApplicationController

  guard all: "recoveries.view"
  # "Short" installments where the customer paid less than the scheduled amount.
  def index
    @from = params[:from].presence&.to_date || Date.current.beginning_of_month
    @to = params[:to].presence&.to_date || Date.current

    plans = InstallmentPlan.shop.where("short_amount > 0 OR (paid_amount > 0 AND paid_amount < amount)")
                          .includes(sale: %i[customer agent])
                          .where(due_date: @from..@to)
                          .order(due_date: :desc)

    @rows = plans.map do |plan|
      sale = plan.sale
      {
        plan: plan,
        sale: sale,
        customer: sale.customer,
        short: plan.short_amount.to_d.positive? ? plan.short_amount.to_d : plan.remaining,
        age: (Date.current - plan.due_date).to_i
      }
    end

    @totals = {
      count: @rows.size,
      short: @rows.sum { |row| row[:short] },
      oldest: @rows.map { |row| row[:age] }.max.to_i
    }
  end
end