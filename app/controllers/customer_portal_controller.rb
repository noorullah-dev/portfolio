# Customer portal. A portal login only ever sees the signed-in customer's own
# account: sales, instalment plans, payments, reminders, documents and account
# statements. Shop costs, expenses, other customers and every management screen
# are unreachable because they live behind different controllers/permissions.
class CustomerPortalController < ApplicationController
  guard all: "portal.view"

  before_action :require_portal_user!
  before_action :set_customer

  def show
    @customer = @portal_customer
    @sales = @portal_customer.sales.recent.includes(:payment_mode)
    @plans = portal_plans(@portal_customer.active_sales)
    @payments = @portal_customer.installment_payments.recent.includes(:payment_mode).limit(20)
    @reminders = @portal_customer.installment_reminders.order(sent_at: :desc).limit(10)
    @documents = @portal_customer.vehicle_documents.order(created_at: :desc)

    render "portal/show"
  end

  def statement
    @customer = @portal_customer
    @sales = @portal_customer.sales.includes(:payment_mode).order(sale_date: :desc, id: :desc)
    @payments = @portal_customer.installment_payments.recent.includes(:payment_mode).limit(100)
    @plans = portal_plans(@portal_customer.sales)

    render "portal/statement"
  end

  private

  # A portal login carries no business_id, so Current.shop is empty by design.
  # Plans are therefore scoped to the signed-in customer's own business and to
  # that customer's sales - never to whatever shop happens to be current.
  def portal_plans(sales)
    InstallmentPlan.where(business_id: @portal_customer.business_id,
                          sale_id: sales.select(:id)).order(:due_date)
  end

  def require_portal_user!
    return if current_user&.customer_portal?

    redirect_to login_path, alert: "This area is for customer logins."
  end

  def set_customer
    @portal_customer = current_user.customer
    if @portal_customer.blank?
      redirect_to login_path, alert: "Your login is not linked to a customer account yet."
      return
    end
  end
end
