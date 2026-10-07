class Branch < ApplicationRecord
  include TenantScoped

  TYPES = %w[main sub].freeze

  belongs_to :business
  belongs_to :provisioned_by, class_name: "User", optional: true

  has_many :users, dependent: :nullify
  has_many :sales, dependent: :restrict_with_error
  has_many :purchases, dependent: :restrict_with_error
  has_many :ledger_entries, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :business_id, case_sensitive: false }
  validates :branch_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: %w[active suspended] }
  validate :allowed_permissions_are_valid
  validate :main_branch_is_preserved

  before_validation :normalise
  after_save :ensure_single_default, if: :saved_change_to_is_default?
  after_create :attach_existing_records

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(branch_type: :desc, name: :asc) }

  def to_s = name

  def default?
    is_default?
  end

  def display_name
    "#{name}#{default? ? ' (main)' : ''}"
  end

  def staff_count
    users.where(status: "active").count
  end

  def record_count
    sales.count + purchases.count
  end

  private

  def normalise
    self.code = name.to_s.parameterize.presence if code.blank?
    self.allowed_permissions = allowed_permissions.map(&:to_s).reject(&:blank?).uniq unless allowed_permissions.nil?
  end

  def allowed_permissions_are_valid
    errors.add(:allowed_permissions, "contains permissions that cannot be assigned to branch staff") if
      (Array(allowed_permissions) - Permissions::STAFF_PERMISSIONS).any?
  end

  def main_branch_is_preserved
    return unless persisted? && is_default_in_database && !is_default?
    return if business.branches.where(is_default: true).where.not(id: id).exists?

    errors.add(:is_default, "cannot be cleared until another branch is made the main branch")
  end

  def ensure_single_default
    return unless is_default?

    business.branches.where.not(id: id).update_all(is_default: false)
  end

  # Rows created before this branch existed belong to the shop's main branch;
  # nothing is guessed for other branches.
  def attach_existing_records
    return unless business_id.blank?

    nil
  end
end
