class AccountTransfersController < ApplicationController

  guard all: "installments.transfer"
  before_action :set_transfer, only: %i[show edit update destroy approve]

  def index
    @transfers = AccountTransfer.shop.includes(:customer, :from_customer, :to_customer, :sale)
    @transfers = @transfers.where(status: params[:status]) if params[:status].present?
    @transfers = @transfers.order(transfer_date: :desc, id: :desc)

    @pending_count = AccountTransfer.shop.where(status: "pending").count
  end

  def show; end

  def new
    @transfer = AccountTransfer.new(transfer_date: Date.current)
    load_collections
  end

  def create
    @transfer = AccountTransfer.new(transfer_params)
    @transfer.created_by = current_user
    @transfer.customer_id = @transfer.from_customer_id

    if @transfer.save
      redirect_to account_transfers_path, notice: "Transfer recorded and pending approval."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_collections
  end

  def update
    if @transfer.update(transfer_params)
      redirect_to account_transfers_path, notice: "Transfer updated."
    else
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    @transfer.update!(status: "approved")
    redirect_to account_transfers_path, notice: "Transfer approved."
  end

  def destroy
    @transfer.destroy
    redirect_to account_transfers_path, notice: "Transfer deleted."
  end

  private

  def set_transfer
    @transfer = AccountTransfer.shop.includes(:customer, :from_customer, :to_customer).find(params[:id])
  end

  def load_collections
    @customers = Customer.shop.active.order(:name)
    @sales = Sale.shop.includes(:customer).where(status: %w[completed delivered]).order(sale_date: :desc)
  end

  def transfer_params
    params.require(:account_transfer).permit(:transfer_date, :from_customer_id, :to_customer_id, :sale_id,
                                               :stock_unit_id, :remaining_balance, :fee, :remarks)
  end
end