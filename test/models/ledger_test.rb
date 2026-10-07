require "test_helper"

class LedgerTest < ActiveSupport::TestCase
  setup do
    @business = create_business(name: "Alpha Motors")
    @branch = create_branch(business: @business)
    @admin = create_user(business: @business, role: "shop_admin", branch: @branch, username: "ledgeradmin")
    @cash_account = ChartOfAccount.create!(business: @business, name: "Cash", code: "1000", account_type: "asset")
    @sales_account = ChartOfAccount.create!(business: @business, name: "Vehicle Sales", code: "4000", account_type: "income")
    @customer = Customer.create!(business: @business, name: "Ledger Buyer", phone: "03001239999")
  end

  test "a posting is rejected unless it balances" do
    error = assert_raises(LedgerPosting::UnbalancedError) do
      LedgerPosting.call(date: Date.current, source_type: "Test", source_id: 1, source_no: "T-1",
                         created_by: @admin,
                         lines: [{ account: @cash_account, debit: 100 },
                                 { account: @sales_account, credit: 90 }])
    end
    assert_match(/balanc/i, error.message)
    assert_equal 0, LedgerEntry.where(source_type: "Test").count
  end

  test "a balanced posting writes equal debits and credits stamped with the shop" do
    assert_difference -> { LedgerEntry.count }, 2 do
      LedgerPosting.call(date: Date.current, source_type: "Test", source_id: 1, source_no: "T-1",
                         created_by: @admin,
                         lines: [{ account: @cash_account, debit: 100 },
                                 { account: @sales_account, credit: 100 }])
    end

    entries = LedgerEntry.where(source_type: "Test")
    assert_equal entries.sum(:debit), entries.sum(:credit)
    entries.each do |entry|
      assert_equal @business.id, entry.business_id, "ledger rows belong to the signed-in shop"
      assert_equal @admin.id, entry.created_by_id
    end
  end

  test "an account balance follows its entries" do
    as(@admin) do
    LedgerPosting.call(date: Date.current, source_type: "Test", source_id: 2, source_no: "T-2",
                       created_by: @admin,
                       lines: [{ account: @cash_account, debit: 500 },
                               { account: @sales_account, credit: 500 }])

    assert_equal 500, balance(@cash_account)
    assert_equal(-500, balance(@sales_account))
    end
  end

  def balance(account)
    entries = LedgerEntry.shop.for_account(account.id)
    entries.sum(:debit) - entries.sum(:credit)
  end

  test "posting a journal voucher writes the debit and the credit side" do
    as(@admin) do
      voucher = JournalVoucher.create!(voucher_date: Date.current, description: "Rent",
                                       status: "draft", posted_by: @admin)
      voucher.lines.create!(account: @cash_account, debit: 100, remarks: "Dr")
      voucher.lines.create!(account: @sales_account, credit: 100, remarks: "Cr")

      voucher.post!(user: @admin)

      assert voucher.reload.posted?
      entries = LedgerEntry.shop.where(source_type: "JournalVoucher", source_id: voucher.id)
      assert_equal 2, entries.count
      assert_equal 100, entries.sum(:debit)
      assert_equal 100, entries.sum(:credit)
    end
  end

  test "one shop's ledger is invisible to another" do
    LedgerPosting.call(date: Date.current, source_type: "Test", source_id: 3, source_no: "T-3",
                       created_by: @admin,
                       lines: [{ account: @cash_account, debit: 250 },
                               { account: @sales_account, credit: 250 }])

    other_shop = create_business(name: "Beta Motors")
    create_branch(business: other_shop, name: "Beta Main")
    stranger = create_user(business: other_shop, role: "shop_admin", username: "ledgerstranger")

    as(stranger) do
      assert_equal 0, LedgerEntry.shop.where(source_type: "Test").count
      assert_equal 0, LedgerEntry.shop.for_account(@cash_account.id).sum(:debit)
    end
  end
end
