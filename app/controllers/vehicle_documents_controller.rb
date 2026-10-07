class VehicleDocumentsController < ApplicationController

  guard index: "vehicle_documents.view", create: "vehicle_documents.manage", destroy: "vehicle_documents.manage"
  before_action :set_sale

  def index
    @documents = @sale ? @sale.vehicle_documents : VehicleDocument.shop.where(customer_id: params[:customer_id])
    @customers = Customer.shop.active.order(:name)
  end

  def create
    @document = @sale.vehicle_documents.new(document_params)
    @document.received = params[:received].present?

    if @document.save
      redirect_back fallback_location: (@sale ? sale_path(@sale) : vehicle_documents_path),
                    notice: "Document tracked."
    else
      redirect_back fallback_location: (@sale ? sale_path(@sale) : vehicle_documents_path),
                    alert: @document.errors.full_messages.to_sentence
    end
  end

  def destroy
    document = VehicleDocument.shop.find(params[:id])
    sale = document.sale
    document.destroy

    redirect_to(sale ? sale_path(sale) : vehicle_documents_path, notice: "Document removed.")
  end

  private

  def set_sale
    @sale = Sale.shop.find(params[:sale_id]) if params[:sale_id].present?
  end

  def document_params
    params.fetch(:vehicle_document, {}).permit(:document_type, :notes, :expected_date, :reference_no, :remarks)
  end
end