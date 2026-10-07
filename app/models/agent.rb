class Agent < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  has_many :customers
  has_many :agent_commissions
  has_many :sales

  validates :name, presence: true

  scope :active, -> { where(status: 'active').order(:name) }

  def total_earned
    agent_commissions.sum(:earned_amount)
  end

  def total_paid
    agent_commissions.sum(:paid_amount)
  end

  def balance
    total_earned - total_paid
  end
end
