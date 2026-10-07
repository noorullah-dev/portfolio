class LedgerPosting
  class UnbalancedError < StandardError; end

  Entry = Struct.new(
    :account, :debit, :credit, :particulars, :party_type, :party_id,
    keyword_init: true
  )

  class << self
    def call(date:, lines:, source_type: nil, source_id: nil, source_no: nil, created_by: nil)
      entries = normalise(lines)
      total_debit = entries.sum(&:debit)
      total_credit = entries.sum(&:credit)

      if total_debit <= 0 && total_credit <= 0
        raise UnbalancedError, "Ledger posting has no amounts"
      end

      if (total_debit - total_credit).abs >= BigDecimal("0.01")
        raise UnbalancedError,
              "Ledger posting is not balanced: debit #{total_debit} vs credit #{total_credit}"
      end

      # Books created outside a request (console, seeds, jobs) have no Current
      # context, so the tenant is taken from whoever is doing the posting.
      business = Current.business_id || created_by&.business_id
      branch = Current.branch_id || created_by&.branch_id

      entries.map do |entry|
        LedgerEntry.create!(
          business_id: business,
          branch_id: branch,
          entry_date: date,
          account: entry.account,
          debit: entry.debit,
          credit: entry.credit,
          source_type: source_type,
          source_id: source_id,
          source_no: source_no,
          party_type: entry.party_type,
          party_id: entry.party_id,
          particulars: entry.particulars,
          created_by: created_by
        )
      end
    end

    private

    def normalise(lines)
      Array(lines).map do |line|
        entry = line.is_a?(Entry) ? line : Entry.new(**line.transform_keys(&:to_sym))
        raise ArgumentError, "account is required" if entry.account.nil?

        Entry.new(
          account: entry.account,
          debit: entry.debit.to_d,
          credit: entry.credit.to_d,
          particulars: entry.particulars,
          party_type: entry.party_type,
          party_id: entry.party_id
        )
      end
    end
  end
end
