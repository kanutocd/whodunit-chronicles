# frozen_string_literal: true

require 'test_helper'

class LedgerTest < Minitest::Test
  def test_default_capabilities_are_safe_noops
    ledger = Whodunit::Chronicles::Ledger.new
    entry = Whodunit::Chronicles::LedgerEntry.from_change_event(sample_change_event)

    assert_same ledger, ledger.prepare!
    assert_same ledger, ledger.ensure_indexes!
    assert_same ledger, ledger.partition_for(entry)
  end

  def test_append_must_be_implemented
    error = assert_raises(NotImplementedError) do
      Whodunit::Chronicles::Ledger.new.append(nil)
    end

    assert_match(/must implement #append/, error.message)
  end
end
