# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
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

  class FailingConnection
    def execute(_sql, _binds = nil)
      raise RuntimeError, 'database offline'
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

  def test_append_reraises_non_constraint_errors
    ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: 'audit.db', connection: FailingConnection.new)

    error = assert_raises(RuntimeError) { ledger.append(sample_entry) }

    assert_equal 'database offline', error.message
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
    with_sqlite_path do |path|
      ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: path)

      ledger.prepare!

      assert ledger.status.fetch(:prepared)
    end
  end

  def test_appends_entry_to_real_database
    with_sqlite_path do |path|
      ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: path)
      ledger.prepare!

      entry = sample_entry
      assert_same entry, ledger.append(entry)

      row = SQLite3::Database.new(path).execute(<<~SQL).first
        SELECT event_id, namespace, entity, identity, operation, actor, changes, metadata, payload
        FROM whodunit_chronicles_entries
      SQL

      assert_equal entry.event_id, row[0]
      assert_equal 'public', row[1]
      assert_equal 'users', row[2]
      assert_equal '{"id":1}', row[3]
      assert_equal 'insert', row[4]
      assert_equal '{"id":42}', row[5]
      assert_includes row[6], '"name":"id"'
      assert_includes row[7], '"transaction_id":"tx-1"'
      assert_includes row[8], '"table":"users"'
    end
  end

  def test_status_counts_entries_in_custom_table
    with_sqlite_path do |path|
      ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: path, table_name: 'audit_entries')
      ledger.prepare!
      ledger.append(sample_entry)

      assert_equal(
        { adapter: 'sqlite', path: path, table_name: 'audit_entries', prepared: true, entries: 1 },
        ledger.status
      )
    end
  end

  def test_unique_event_index_raises_append_error_for_duplicate_entries
    with_sqlite_path do |path|
      ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: path)
      ledger.prepare!
      ledger.ensure_indexes!

      ledger.append(sample_entry)

      error = assert_raises(Whodunit::Chronicles::AppendError) { ledger.append(sample_entry) }

      assert_includes error.message, sample_entry.event_id
      assert_instance_of SQLite3::ConstraintException, error.cause
      assert_equal 1, ledger.status.fetch(:entries)
    end
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

  private

  def with_sqlite_path
    Dir.mktmpdir('whodunit-chronicles-sqlite') do |directory|
      yield File.join(directory, 'ledger.db')
    end
  end
end
