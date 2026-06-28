# frozen_string_literal: true

require 'test_helper'
require 'whodunit/chronicles/ledgers/sqlite_ledger'

class SQLiteLedgerTest < Minitest::Test
  class FakeConnection
    attr_reader :calls

    def initialize(table_exists: true, count: 2)
      @table_exists = table_exists
      @count = count
      @calls = []
    end

    def execute(sql, binds = nil)
      @calls << [sql, binds]
      return [['whodunit_chronicles_entries']] if sql.include?('sqlite_master') && @table_exists
      return [[@count]] if sql.include?('COUNT(*)')

      []
    end
  end

  def test_prepare_creates_table
    connection = FakeConnection.new
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'audit.db', connection: connection)

    assert_same ledger, ledger.prepare!
    assert_includes connection.calls.first.first, 'CREATE TABLE IF NOT EXISTS'
  end

  def test_ensure_indexes_creates_standard_indexes
    connection = FakeConnection.new
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'audit.db', connection: connection)

    assert_same ledger, ledger.ensure_indexes!
    assert_equal 3, connection.calls.length
    assert(connection.calls.all? { |sql, _binds| sql.include?('CREATE') })
  end

  def test_append_inserts_serialized_entry
    connection = FakeConnection.new
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'audit.db', connection: connection)
    entry = sample_entry

    assert_same entry, ledger.append(entry)
    sql, binds = connection.calls.first

    assert_includes sql, 'INSERT INTO'
    assert_equal entry.event_id, binds.first
    assert_equal '{"id":1}', binds[5]
  end

  def test_status_reports_prepared_ledger
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(
      path: 'audit.db',
      table_name: 'custom_entries',
      connection: FakeConnection.new(count: 7)
    )

    assert_equal({ adapter: 'sqlite', path: 'audit.db', table_name: 'custom_entries', prepared: true, entries: 7 },
                 ledger.status)
  end

  def test_status_reports_unprepared_ledger
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(
      path: 'audit.db',
      connection: FakeConnection.new(table_exists: false)
    )

    refute ledger.status.fetch(:prepared)
    assert_nil ledger.status.fetch(:entries)
  end
end

class SQLiteLedgerLazyConnectionTest < Minitest::Test
  def test_lazy_connection_uses_sqlite3_database
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'lazy.db')

    ledger.prepare!

    assert ledger.status.fetch(:prepared)
  end

  def test_append_serializes_non_time_values
    connection = SQLiteLedgerTest::FakeConnection.new
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'audit.db', connection: connection)
    entry = Whodunit::Chronicles::LedgerEntry.new(
      event_id: 'string-time',
      occurred_at: '2026-01-01',
      recorded_at: '2026-01-02',
      namespace: 'public',
      entity: 'users',
      identity: { id: 1 },
      operation: 'insert',
      actor: nil,
      changes: {},
      metadata: {},
      payload: {}
    )

    ledger.append(entry)

    assert_equal '2026-01-01', connection.calls.first.last[1]
  end
end
