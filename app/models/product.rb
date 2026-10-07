class Product < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :brand
  belongs_to :category

  has_many :variants, dependent: :restrict_with_error
  has_many :stock_units

  validates :name, presence: true

  scope :active, -> { where(status: 'active').includes(:brand, :category).order(:name) }

  def display_name
    [brand&.name, name].compact.join(" ")
  end

  def full_name
    [brand&.name, name, category&.name].compact.join(" - ")
  end
end
