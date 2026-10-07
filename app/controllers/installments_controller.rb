class InstallmentsController < ApplicationController

  guard index: "installments.view", show: "installments.view", remind: "installments.remind"
  # POST /installments/:id/remind — logs a reminder for one installment plan.
  def remind
    plan = InstallmentPlan.shop.find(params[:id])
    reminder = plan.reminders.create!(
      sale: plan.sale,
      customer: plan.sale.customer,
      channel: params[:channel].presence || "sms",
      remarks: params[:remarks].presence || "Payment reminder sent"
    )

    redirect_back fallback_location: (params[:return_to].presence || sales_path),
                  notice: "Reminder #{reminder.id} logged for #{plan.sale.customer.display_name}."
  end
end