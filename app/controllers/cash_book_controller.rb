class CashBookController < ApplicationController

  guard all: "cash_book.view"
  def index
    @from = params[:from].presence&.to_date || Date.current.beginning_of_month
    @to = params[:to].presence&.to_date || Date.current.end_of_month

    scope = CashBookEntry.shop.between(@from, @to)
    scope = scope.where(payment_mode_id: params[:payment_mode_id]) if params[:payment_mode_id].present?
    scope = scope.where(direction: params[:direction]) if params[:direction].present?

    @entries = scope.includes(:payment_mode, :created_by).order(:entry_date, :id).to_a
    @payment_modes = PaymentMode.shop.cash_first

    @opening = CashBookEntry.shop.where(entry_date: ...@from).sum { |e| e.signed_amount }

    running = @opening.to_d
    @rows = @entries.map do |entry|
      running += entry.signed_amount
      [entry, running]
    end

    @totals = {
      in: @entries.sum { |e| e.direction == "in" ? e.amount.to_d : 0.to_d },
      out: @entries.sum { |e| e.direction == "out" ? e.amount.to_d : 0.to_d }
    }
    @closing = @opening.to_d + @totals[:in] - @totals[:out]

    @by_mode = @entries.group_by { |e| e.payment_mode&.name || "Unassigned" }.map do |name, list|
      [name, list.sum { |e| e.direction == "in" ? e.amount.to_d : -e.amount.to_d }]
    end
  end
end