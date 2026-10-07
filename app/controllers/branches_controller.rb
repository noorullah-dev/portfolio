# Branch management. A shop admin owns the branch structure of their own shop;
# the owner can inspect it read-only through the owner console.
class BranchesController < ApplicationController
  guard index: "branches.view", show: "branches.view",
        new: "branches.create", create: "branches.create",
        edit: "branches.edit", update: "branches.edit",
        destroy: "branches.delete"

  shop_admin_only :new, :create, :edit, :update, :destroy
  before_action :set_branch, only: %i[show edit update destroy]
  before_action :ensure_own_tenant!, only: %i[show edit update destroy]

  def index
    @branches = Branch.shop.ordered.map do |branch|
      { branch: branch, staff: branch.staff_count, sales: branch.sales.count,
        purchases: branch.purchases.count }
    end
  end

  def show
    @staff = @branch.users.order(:full_name)
    @sales_count = @branch.sales.count
    @recent_sales = Sale.shop.where(branch_id: @branch.id).order(sale_date: :desc, id: :desc).limit(10)
  end

  def new
    @branch = Branch.new(business_id: business&.id, branch_type: "sub", status: "active")
  end

  def create
    @branch = Branch.new(branch_params.merge(business_id: business&.id, provisioned_by: current_user))
    @branch.is_default = true if @branch.branch_type == "main" && Branch.shop.where(is_default: true).none?

    if @branch.save
      Current.audit!(:"branch.create", record: @branch, summary: "Created branch #{@branch.name}",
                     changes: { "allowed_permissions" => @branch.allowed_permissions })
      redirect_to branches_path, notice: "Branch #{@branch.name} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @branch.update(branch_params)
      Current.audit!(:"branch.update", record: @branch, summary: "Updated branch #{@branch.name}",
                     changes: { "allowed_permissions" => @branch.allowed_permissions })
      redirect_to branches_path, notice: "Branch updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @branch.is_default?
      redirect_to branches_path, alert: "The main branch cannot be deleted."
    elsif @branch.sales.exists? || @branch.purchases.exists?
      redirect_to branches_path, alert: "This branch already has transactions. Suspend it instead."
    elsif @branch.users.exists?
      redirect_to branches_path, alert: "Reassign this branch's staff before deleting it."
    else
      name = @branch.name
      if @branch.destroy
        Current.audit!(:"branch.delete", summary: "Deleted branch #{name}")
        redirect_to branches_path, notice: "Branch #{name} deleted."
      else
        redirect_to branches_path, alert: @branch.errors.full_messages.to_sentence
      end
    end
  end

  private

  def set_branch
    @branch = Branch.shop.find(params[:id])
  end

  def ensure_own_tenant!
    return if owner? || @branch.business_id == business&.id

    redirect_to branches_path, alert: "That branch belongs to another company."
  end

  def branch_params
    input = params.require(:branch)
    attributes = input.permit(:name, :code, :branch_type, :address, :city, :phone, :status, :is_default)
    if input[:permission_mode].present?
      attributes[:allowed_permissions] = input[:permission_mode] == "custom" ? Array(input.permit(allowed_permissions: [])[:allowed_permissions]).reject(&:blank?) : nil
    end
    attributes
  end
end
