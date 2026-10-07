class PostDatedCheque < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :customer
  belongs_to :sale, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  def pending?
    status == "pending"
  end

  def deposited?
    status == "deposited"
  end

  def cleared?
    status == "cleared"
  end

  def bounced?
    status == "bounced"
  end

  scope :recent, -> { order(cheque_date: :desc, id: :desc) }
  scope :pending, -> { where(status: "pending") }

  def deposit!
    update!(status: "deposited", deposited_on: Date.current)
  end

  def bounce!
    update!(status: "bounced")
  end

  def clear!
    update!(status: "cleared")
  end
end
