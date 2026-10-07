class RoznamchasController < ApplicationController

  guard all: "installments.view"
  # Reminder letters (roznamcha) for customers with overdue installments.
  def index
    @from = params[:from].presence&.to_date || Date.current.beginning_of_month
    @to = params[:to].presence&.to_date || Date.current

    plans = InstallmentPlan.shop.unpaid
                          .includes(sale: %i[customer agent])
                          .where(due_date: @from..@to)
                          .order(:due_date)

    @rows = plans.filter_map do |plan|
      sale = plan.sale
      customer = sale.customer
      next if customer.nil?

      {
        plan: plan,
        sale: sale,
        customer: customer,
        remaining: plan.remaining,
        days_overdue: plan.days_overdue
      }
    end

    @customers = @rows.group_by { |row| row[:customer] }
                      .map { |customer, rows| [customer, rows.sum { |row| row[:remaining] }] }
                      .sort_by { |_, amount| -amount }

    @total = @rows.sum { |row| row[:remaining] }
  end
end