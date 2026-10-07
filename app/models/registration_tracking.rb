class RegistrationTracking < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[pending submitted at_office returned received rejected cancelled].freeze

  belongs_to :sale
  belongs_to :customer
  belongs_to :agent, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  def days_pending
    return 0 if letter_received?

    ((Date.current - (submitted_date || Date.current)).to_i).clamp(0..)
  end

  validates :status, inclusion: { in: STATUSES }
  validates :expected_return_date, comparison: { greater_than_or_equal_to: :submitted_date,
                                                 allow_nil: true }

  def overdue?
    expected_return_date.present? && expected_return_date < Date.current && !letter_received?
  end
end
