class AgentCommissionsController < ApplicationController

  guard index: "commissions.view", show: "commissions.view", new: "commissions.create", create: "commissions.create", edit: "commissions.edit", update: "commissions.edit", destroy: "commissions.delete"
  before_action :set_commission, only: %i[show edit update destroy]

  def index
    @commissions = AgentCommission.shop.includes(:agent, :sale)
    @commissions = @commissions.where(agent_id: params[:agent_id]) if params[:agent_id].present?
    @commissions = @commissions.where(status: params[:status]) if params[:status].present?
    @commissions = @commissions.order(created_at: :desc)

    @totals = {
      earned: AgentCommission.shop.sum(:earned_amount),
      paid: AgentCommissionPayment.shop.sum(:amount),
      pending: AgentCommission.shop.sum(:earned_amount) - AgentCommissionPayment.sum(:amount),
      unpaid_count: AgentCommission.shop.where(status: %w[pending partial]).count
    }
    @agents = Agent.shop.active.order(:name)
  end

  def show
    @payments = @commission.payments.recent.includes(:payment_mode)
  end

  def edit
    load_collections
  end

  def update
    if @commission.update(commission_params)
      redirect_to agent_commissions_path, notice: "Commission updated."
    else
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def new
    @commission = AgentCommission.new(sale_date: Date.current)
    load_collections
  end

  def create
    @commission = AgentCommission.new(commission_params)

    @commission.save
    redirect_to agent_commissions_path, notice: "Commission recorded."
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    @commission.errors.add(:sale_id, "already has a commission recorded") if @commission.errors[:sale_id].empty?
    load_collections
    render :new, status: :unprocessable_entity
  end

  def destroy
    @commission.destroy
    redirect_to agent_commissions_path, notice: "Commission deleted."
  end

  private

  def set_commission
    @commission = AgentCommission.shop.includes(:agent, :sale).find(params[:id])
  end

  def load_collections
    @agents = Agent.shop.active.order(:name)
    # a sale can only carry one commission, so keep those out of the picker
    @sales = Sale.shop.includes(:customer).where.not(agent_id: nil)
                  .where.not(id: AgentCommission.shop.select(:sale_id)).order(sale_date: :desc)
  end

  def commission_params
    params.require(:agent_commission).permit(:agent_id, :sale_id, :sale_date, :basis_amount,
                                              :commission_type, :commission_value, :earned_amount,
                                              :status)
  end
end