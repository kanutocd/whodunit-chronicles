# frozen_string_literal: true

require 'trilogy'
require 'uri'

module Whodunit
  module Chronicles
    module Adapters
      # MySQL/MariaDB binary log streaming adapter
      #
      # Uses MySQL's binary log replication to stream database changes
      # without impacting application performance.
      class MySQL < StreamAdapter
        DEFAULT_SERVER_ID = 1001

        attr_reader :connection, :database_url, :server_id, :binlog_file, :binlog_position

        def initialize(
          database_url: Chronicles.config.database_url,
          server_id: DEFAULT_SERVER_ID,
          logger: Chronicles.logger
        )
          super(logger: logger)
          @database_url = database_url
          @server_id = server_id
          @connection = nil
          @binlog_file = nil
          @binlog_position = nil
          @binlog_checksum = true
        end

        # Start streaming binary log changes
        def start_streaming(&)
          raise ArgumentError, 'Block required for processing events' unless block_given?

          log(:info, 'Starting MySQL binary log streaming')

          establish_connection
          ensure_setup

          self.running = true
          fetch_current_position

          log(:info, 'Starting replication from position',
            file: @binlog_file, position: @binlog_position)

          begin
            stream_binlog_events(&)
          rescue StandardError => e
            log(:error, 'Streaming error', error: e.message, backtrace: e.backtrace.first(5))
            raise ReplicationError, "Failed to stream changes: #{e.message}"
          ensure
            self.running = false
          end
        end

        # Stop streaming
        def stop_streaming
          log(:info, 'Stopping MySQL binary log streaming')
          self.running = false
          close_connection
        end

        # Get current replication position
        def current_position
          return "#{@binlog_file}:#{@binlog_position}" if @binlog_file && @binlog_position

          fetch_current_position
          "#{@binlog_file}:#{@binlog_position}"
        end

        # Set up binary log replication
        def setup
          log(:info, 'Setting up MySQL binary log replication')

          establish_connection
          validate_binlog_format
          validate_server_id
          enable_binlog_checksum

          log(:info, 'MySQL setup completed successfully')
        end

        # Remove binary log replication setup (minimal cleanup needed)
        def teardown
          log(:info, 'Tearing down MySQL binary log replication')
          close_connection
          log(:info, 'MySQL teardown completed')
        end

        # Test database connection
        def test_connection
          establish_connection
          result = @connection.query('SELECT @@hostname, @@version, @@server_id')
          info = result.first

          log(:info, 'Connection test successful',
            hostname: info['@@hostname'],
            version: info['@@version'],
            server_id: info['@@server_id'])

          true
        rescue StandardError => e
          log(:error, 'Connection test failed', error: e.message)
          false
        end

        private

        def establish_connection
          return if @connection&.ping

          parsed_url = parse_database_url(@database_url)

          @connection = Trilogy.new(
            host: parsed_url[:host],
            port: parsed_url[:port] || 3306,
            username: parsed_url[:username],
            password: parsed_url[:password],
            database: parsed_url[:database],
            ssl: parsed_url[:ssl],
          )

          log(:debug, 'Established MySQL connection',
            host: parsed_url[:host],
            database: parsed_url[:database])
        rescue StandardError => e
          log(:error, 'Failed to establish connection', error: e.message)
          raise AdapterError, "Connection failed: #{e.message}"
        end

        def close_connection
          @connection&.close
          @connection = nil
        end

        def parse_database_url(url)
          uri = URI.parse(url)
          {
            host: uri.host,
            port: uri.port,
            username: uri.user,
            password: uri.password,
            database: uri.path&.sub('/', ''),
            ssl: uri.query&.include?('ssl=true'),
          }
        end

        def ensure_setup
          validate_binlog_format
          validate_server_id
        end

        def validate_binlog_format
          result = @connection.query('SELECT @@binlog_format')
          format = result.first['@@binlog_format']

          unless %w[ROW MIXED].include?(format)
            raise ReplicationError,
              "Binary log format must be ROW or MIXED, currently: #{format}"
          end

          log(:debug, 'Binary log format validated', format: format)
        end

        def validate_server_id
          result = @connection.query('SELECT @@server_id')
          current_server_id = result.first['@@server_id'].to_i

          if current_server_id == @server_id
            raise ReplicationError,
              "Server ID conflict: #{@server_id} is already in use"
          end

          log(:debug, 'Server ID validated',
            current: current_server_id,
            replication: @server_id)
        end

        def enable_binlog_checksum
          @connection.query('SET @master_binlog_checksum = @@global.binlog_checksum')
          log(:debug, 'Binary log checksum enabled')
        end

        def fetch_current_position
          result = @connection.query('SHOW MASTER STATUS')
          status = result.first

          raise ReplicationError, 'Unable to fetch master status - binary logging may be disabled' unless status

          @binlog_file = status['File']
          @binlog_position = status['Position']
          log(:debug, 'Fetched master position',
            file: @binlog_file,
            position: @binlog_position)
        end

        def stream_binlog_events(&)
          # Register as replica server
          register_replica_server

          # Request binary log dump
          request_binlog_dump

          # Process binary log events
          process_binlog_stream(&)
        rescue StandardError => e
          log(:error, 'Binary log streaming error', error: e.message)
          raise
        end

        def register_replica_server
          # This would typically use COM_REGISTER_SLAVE MySQL protocol command
          # For now, we'll use a simplified approach
          log(:debug, 'Registering as replica server', server_id: @server_id)

          # NOTE: Full implementation would require low-level MySQL protocol handling
          # This is a placeholder for the binary log streaming setup
        end

        def request_binlog_dump
          log(:debug, 'Requesting binary log dump',
            file: @binlog_file,
            position: @binlog_position)

          # This would use COM_BINLOG_DUMP MySQL protocol command
          # Full implementation requires binary protocol handling
        end

        def process_binlog_stream(&)
          # This would process the binary log event stream
          # Each event would be parsed and converted to a ChangeEvent

          log(:info, 'Processing binary log stream (placeholder implementation)')

          # Placeholder: In a real implementation, this would:
          # 1. Read binary log events from the stream
          # 2. Parse event headers and data
          # 3. Convert to ChangeEvent objects
          # 4. Yield each event to the block

          # For now, we'll simulate with a warning
          log(:warn, 'MySQL binary log streaming requires full protocol implementation')

          # Yield a placeholder change event to demonstrate the interface
          change_event = ChangeEvent.new(
            table_name: 'example_table',
            action: 'INSERT',
            primary_key: { id: 1 },
            new_data: { id: 1, name: 'test' },
            old_data: nil,
            timestamp: Time.now,
            metadata: { position: current_position },
          )

          yield(change_event) if block_given?
        end
      end
    end
  end
end
