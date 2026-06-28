# frozen_string_literal: true

require 'json'
require 'time'
require_relative '../ledger'

module Whodunit
  module Chronicles
    module Ledgers
      # SQLite-backed embedded durable ledger.
      #
      # SQLiteLedger is the default solid local book. It can create its table,
      # create indexes, report status, and append immutable ledger entries. The
      # sqlite3 gem is loaded lazily only when a connection is not injected.
      class SQLiteLedger < Ledger
        # Default SQLite table for entries.
        DEFAULT_TABLE = 'whodunit_chronicles_entries'

        # @return [String] path to the SQLite database file
        attr_reader :path

        # @return [String] table receiving entries
        attr_reader :table_name

        # Create a SQLite-backed ledger.
        #
        # @param path [String] path to the SQLite database file
        # @param table_name [String] table receiving entries
        # @param connection [Object, nil] optional SQLite-compatible connection
        def initialize(path:, table_name: DEFAULT_TABLE, connection: nil)
          @path = path.to_s
          @table_name = table_name.to_s
          @connection = connection
        end

        # Create the entries table if needed.
        #
        # @return [SQLiteLedger] this ledger
        def prepare!
          connection.execute(<<~SQL)
            CREATE TABLE IF NOT EXISTS #{quoted_table_name} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_id TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              recorded_at TEXT NOT NULL,
              namespace TEXT,
              entity TEXT,
              identity TEXT,
              operation TEXT NOT NULL,
              actor TEXT,
              changes TEXT,
              metadata TEXT,
              payload TEXT NOT NULL
            )
          SQL
          self
        end

        # Create indexes useful for audit lookup and de-duplication.
        #
        # @return [SQLiteLedger] this ledger
        def ensure_indexes!
          connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS #{index_name(:event_id)} ON #{quoted_table_name} (event_id)")
          connection.execute("CREATE INDEX IF NOT EXISTS #{index_name(:entity)} ON #{quoted_table_name} (namespace, entity)")
          connection.execute("CREATE INDEX IF NOT EXISTS #{index_name(:occurred_at)} ON #{quoted_table_name} (occurred_at)")
          self
        end

        # Append one ledger entry.
        #
        # @param entry [LedgerEntry] entry to append
        # @return [LedgerEntry] appended entry
        def append(entry)
          connection.execute(<<~SQL, bind_values(entry))
            INSERT INTO #{quoted_table_name} (
              event_id, occurred_at, recorded_at, namespace, entity,
              identity, operation, actor, changes, metadata, payload
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          SQL
          entry
        end

        # Return lightweight operational status for this ledger.
        #
        # @return [Hash<Symbol, Object>] ledger status
        def status
          {
            adapter: 'sqlite',
            path: path,
            table_name: table_name,
            prepared: prepared?,
            entries: prepared? ? count_entries : nil
          }
        end

        private

        # Return the SQLite connection, creating it lazily when required.
        def connection
          @connection ||= begin
            require 'sqlite3'
            SQLite3::Database.new(path)
          end
        end

        # Build bind values for one entry.
        def bind_values(entry)
          [
            entry.event_id,
            serialize_time(entry.occurred_at),
            serialize_time(entry.recorded_at),
            entry.namespace,
            entry.entity,
            JSON.generate(entry.identity),
            entry.operation.to_s,
            JSON.generate(entry.actor),
            JSON.generate(entry.changes),
            JSON.generate(entry.metadata),
            JSON.generate(entry.payload)
          ]
        end

        # Serialize time-like objects consistently.
        def serialize_time(value)
          return value.iso8601 if value.respond_to?(:iso8601)

          value.to_s
        end

        # Determine whether the entries table exists.
        def prepared?
          rows = connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            [table_name]
          )
          !rows.empty?
        end

        # Count persisted entries.
        def count_entries
          connection.execute("SELECT COUNT(*) FROM #{quoted_table_name}").first.first
        end

        # Quote a SQLite identifier.
        def quote_identifier(identifier)
          %("#{identifier.to_s.gsub('"', '""')}")
        end

        # Quote the configured table name.
        def quoted_table_name
          @quoted_table_name ||= table_name.split('.').map { |part| quote_identifier(part) }.join('.')
        end

        # Build a safe index name from the table and suffix.
        def index_name(suffix)
          quote_identifier("#{table_name.gsub(/\W+/, '_')}_#{suffix}_idx")
        end
      end
    end
  end
end
