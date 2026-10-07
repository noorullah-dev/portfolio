class QistCalculatorController < ApplicationController

  guard all: "calculator.view"
  def show
    @amount = params[:amount].presence || 1_000_000
    @months = params[:months].presence || 12
    @rate = params[:rate].presence || 0
    @down_payment = params[:down_payment].presence || 0
    @result = calculate(@amount, @months, @rate, @down_payment)
  end

  # POST /qist-calculator — same calculation, rendered on the same page.
  def calculate
    @amount = params[:amount]
    @months = params[:months]
    @rate = params[:rate]
    @down_payment = params[:down_payment]
    @result = calculate(@amount, @months, @rate, @down_payment)

    render :show
  end

  private

  def calculate(amount, months, rate, down_payment)
    amount = amount.to_d
    months = months.to_i
    rate = rate.to_d
    down_payment = down_payment.to_d

    financed = [amount - down_payment, 0].max
    months = 1 if months < 1

    monthly_rate = rate / 100.0 / 12.0
    if monthly_rate.zero?
      monthly = financed / months
    else
      factor = (1 + monthly_rate)**months
      monthly = financed * monthly_rate * factor / (factor - 1)
    end

    {
      financed: financed,
      monthly: monthly,
      total_payable: monthly * months,
      total_markup: (monthly * months) - financed,
      first_due_date: Date.current + 1.month,
      schedule: build_schedule(financed, monthly, months)
    }
  end

  def build_schedule(principal, monthly, months)
    balance = principal
    rows = []

    months.times do |index|
      interest = balance * (monthly.zero? ? 0 : 0)
      principal_part = [monthly, balance].min
      balance -= principal_part
      rows << {
        installment_no: index + 1,
        due_date: Date.current + (index + 1).months,
        principal: principal_part,
        payment: monthly,
        balance: [balance, 0].max
      }
    end

    rows
  end
end