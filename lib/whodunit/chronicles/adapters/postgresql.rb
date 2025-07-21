# frozen_string_literal: true

require 'pg'

module Whodunit
  module Chronicles
    module Adapters
      # PostgreSQL logical replication adapter
      #
      # Uses PostgreSQL's logical replication functionality to stream
      # database changes via WAL decoding without impacting application performance.
      class PostgreSQL < StreamAdapter
        DEFAULT_PLUGIN = 'pgoutput'

        attr_reader :connection, :replication_connection, :publication_name, :slot_name

        def initialize(
          database_url: Chronicles.config.database_url,
          publication_name: Chronicles.config.publication_name,
          slot_name: Chronicles.config.replication_slot_name,
          logger: Chronicles.logger
        )
          super(logger: logger)
          @database_url = database_url
          @publication_name = publication_name
          @slot_name = slot_name
          @connection = nil
          @replication_connection = nil
          @last_lsn = nil
        end

        # Start streaming logical replication changes
        def start_streaming(&)
          raise ArgumentError, 'Block required for processing events' unless block_given?

          log(:info, 'Starting PostgreSQL logical replication streaming')

          establish_connections
          ensure_setup

          self.running = true
          self.position = confirmed_flush_lsn || '0/0'

          log(:info, 'Starting replication from LSN', lsn: @position)

          begin
            stream_changes(&)
          rescue StandardError => e
            log(:error, 'Streaming error', error: e.message, backtrace: e.backtrace.first(5))
            raise ReplicationError, "Failed to stream changes: #{e.message}"
          ensure
            self.running = false
          end
        end

        # Stop streaming
        def stop_streaming
          log(:info, 'Stopping PostgreSQL logical replication streaming')
          self.running = false
          close_connections
        end

        # Get current replication position
        def current_position
          @last_lsn || confirmed_flush_lsn
        end

        # Set up logical replication (publication and slot)
        def setup
          log(:info, 'Setting up PostgreSQL logical replication')

          establish_connection
          create_publication
          create_replication_slot

          log(:info, 'PostgreSQL setup completed successfully')
        end

        # Remove logical replication setup
        def teardown
          log(:info, 'Tearing down PostgreSQL logical replication')

          establish_connection
          drop_replication_slot
          drop_publication

          log(:info, 'PostgreSQL teardown completed')
        ensure
          close_connections
        end

        # Test database connection
        def test_connection
          establish_connection
          result = @connection.exec('SELECT current_database(), current_user, version()')
          db_info = result.first

          log(:info, 'Connection test successful',
            database: db_info['current_database'],
            user: db_info['current_user'],
            version: db_info['version'])

          true
        rescue PG::Error => e
          log(:error, 'Connection test failed', error: e.message)
          false
        ensure
          result&.clear
        end

        private

        def establish_connections
          establish_connection
          establish_replication_connection
        end

        def establish_connection
          return if @connection && !@connection.finished?

          @connection = PG.connect(@database_url)
          @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
        end

        def establish_replication_connection
          return if @replication_connection && !@replication_connection.finished?

          # Parse connection URL and add replication parameter
          uri = URI.parse(@database_url)
          repl_params = URI.decode_www_form(uri.query || '')
          repl_params << %w[replication database]
          uri.query = URI.encode_www_form(repl_params)

          @replication_connection = PG.connect(uri.to_s)
        end

        def close_connections
          @connection&.close
          @replication_connection&.close
          @connection = nil
          @replication_connection = nil
        end

        def ensure_setup
          unless publication_exists?
            raise ReplicationError, "Publication '#{publication_name}' does not exist. Run #setup first."
          end

          return if replication_slot_exists?

          raise ReplicationError, "Replication slot '#{slot_name}' does not exist. Run #setup first."
        end

        def stream_changes(&)
          copy_sql = build_copy_statement
          log(:debug, 'Starting COPY command', sql: copy_sql)

          @replication_connection.exec(copy_sql)

          while running?
            data = @replication_connection.get_copy_data(async: false)
            break unless data

            process_wal_data(data, &)
          end
        end

        def build_copy_statement
          options = [
            "proto_version '1'",
            "publication_names '#{publication_name}'",
          ].join(', ')

          "COPY (SELECT * FROM pg_logical_slot_get_changes('#{slot_name}', NULL, NULL, #{options})) TO STDOUT"
        end

        def process_wal_data(data)
          # Parse pgoutput protocol message
          # This is a simplified version - full implementation would need
          # to properly decode the binary protocol
          log(:debug, 'Processing WAL data', size: data.bytesize)

          # For now, we'll parse text-based logical decoding output
          # In production, this should parse the binary pgoutput format
          change_event = parse_logical_message(data)
          yield(change_event) if change_event
        rescue StandardError => e
          log(:error, 'Error processing WAL data', error: e.message, data: data.inspect)
        end

        def parse_logical_message(data)
          # Simplified parser for demonstration
          # Real implementation would parse pgoutput binary protocol
          lines = data.strip.split("\n")
          return unless lines.any?

          # This is a placeholder - would need full pgoutput protocol parsing
          log(:debug, 'Parsed logical message', lines: lines.size)
          nil
        end

        def create_publication
          if publication_exists?
            log(:info, 'Publication already exists', name: publication_name)
            return
          end

          sql = "CREATE PUBLICATION #{publication_name} FOR ALL TABLES"
          @connection.exec(sql)
          log(:info, 'Created publication', name: publication_name)
        end

        def drop_publication
          return unless publication_exists?

          sql = "DROP PUBLICATION IF EXISTS #{publication_name}"
          @connection.exec(sql)
          log(:info, 'Dropped publication', name: publication_name)
        end

        def create_replication_slot
          if replication_slot_exists?
            log(:info, 'Replication slot already exists', name: slot_name)
            return
          end

          sql = "SELECT pg_create_logical_replication_slot('#{slot_name}', '#{DEFAULT_PLUGIN}')"
          result = @connection.exec(sql)
          slot_info = result.first

          log(:info, 'Created replication slot',
            name: slot_name,
            lsn: slot_info['lsn'])
        ensure
          result&.clear
        end

        def drop_replication_slot
          return unless replication_slot_exists?

          sql = "SELECT pg_drop_replication_slot('#{slot_name}')"
          @connection.exec(sql)
          log(:info, 'Dropped replication slot', name: slot_name)
        end

        def publication_exists?
          sql = 'SELECT 1 FROM pg_publication WHERE pubname = $1'
          result = @connection.exec_params(sql, [publication_name])
          exists = result.ntuples.positive?
          result.clear
          exists
        end

        def replication_slot_exists?
          sql = 'SELECT 1 FROM pg_replication_slots WHERE slot_name = $1'
          result = @connection.exec_params(sql, [slot_name])
          exists = result.ntuples.positive?
          result.clear
          exists
        end

        def confirmed_flush_lsn
          sql = 'SELECT confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = $1'
          result = @connection.exec_params(sql, [slot_name])

          if result.ntuples.positive?
            lsn = result.first['confirmed_flush_lsn']
            result.clear
            lsn
          else
            result.clear
            nil
          end
        end
      end
    end
  end
end
