# frozen_string_literal: true

require 'test_helper'
require 'whodunit/chronicles/ledger_factory'

class LedgerFactoryTest < Minitest::Test
  def test_builds_memory_ledger
    ledger = Whodunit::Chronicles::LedgerFactory.build('ledger' => { 'adapter' => 'memory' })

    assert_instance_of Whodunit::Chronicles::Ledgers::MemoryLedger, ledger
  end

  def test_builds_file_ledger_from_symbol_keys
    ledger = Whodunit::Chronicles::LedgerFactory.build(ledger: { adapter: 'file', path: 'events.ndjson' })

    assert_instance_of Whodunit::Chronicles::Ledgers::FileLedger, ledger
    assert_equal 'events.ndjson', ledger.path
  end

  def test_builds_sqlite_ledger_with_default_table
    ledger = Whodunit::Chronicles::LedgerFactory.build('adapter' => 'sqlite', 'path' => 'audit.db')

    assert_instance_of Whodunit::Chronicles::Ledgers::SQLiteLedger, ledger
    assert_equal 'audit.db', ledger.path
    assert_equal Whodunit::Chronicles::Ledgers::SQLiteLedger::DEFAULT_TABLE, ledger.table_name
  end

  def test_builds_sqlite_ledger_with_custom_table
    ledger = Whodunit::Chronicles::LedgerFactory.build('adapter' => 'sqlite', 'path' => 'audit.db',
                                                       'table_name' => 'entries')

    assert_equal 'entries', ledger.table_name
  end

  def test_rejects_unknown_adapter
    error = assert_raises(Whodunit::Chronicles::ConfigurationError) do
      Whodunit::Chronicles::LedgerFactory.build('adapter' => 'oracle')
    end

    assert_includes error.message, 'unsupported ledger adapter'
  end
end
