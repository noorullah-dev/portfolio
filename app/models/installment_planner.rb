class InstallmentPlanner
  class << self
    # Splits a financed amount into equal installments, pushing the rounding
    # remainder onto the final row so the schedule always sums exactly.
    def call(amount:, months:, first_due_date: Date.current)
      amount = amount.to_d.round(2)
      months = months.to_i
      return [] unless amount.positive? && months.positive?

      installment = (amount / months).round(2)
      rows = Array.new(months) do |index|
        {
          installment_no: index + 1,
          due_date: due_date_for(index, first_due_date),
          amount: installment
        }
      end
      rows.last[:amount] += (amount - (installment * months))
      rows.each { |row| row[:amount] = row[:amount].round(2) }
      rows
    end

    def monthly_installment(amount:, months:)
      return 0.to_d unless months.to_i.positive?

      (amount.to_d / months.to_i).round(2)
    end

    private

    def due_date_for(index, first_due_date)
      (first_due_date + index.months).to_date
    end
  end
end