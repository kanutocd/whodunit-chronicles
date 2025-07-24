# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    module Adapters
      class MySQLTest < Minitest::Test
        def setup
          super
          @adapter = MySQL.new(
            database_url: 'mysql://localhost/test',
            logger: mock_logger,
          )
        end

        def test_initialization
          adapter = MySQL.new(logger: mock_logger)

          assert_equal 1001, adapter.server_id
        end

        def test_initialization_with_custom_options
          adapter = MySQL.new(
            database_url: 'mysql://localhost/custom',
            server_id: 2002,
            logger: mock_logger,
          )

          assert_equal 'mysql://localhost/custom', adapter.database_url
          assert_equal 2002, adapter.server_id
        end

        def test_start_streaming_requires_block
          mock_connection
          @adapter.stubs(:ensure_setup)

          error = assert_raises ArgumentError do
            @adapter.start_streaming
          end

          assert_includes error.message, 'Block required'
        end

        def test_start_streaming_calls_stream_binlog_events
          mock_connection
          @adapter.stubs(:ensure_setup)
          @adapter.stubs(:fetch_current_position)
          @adapter.expects(:stream_binlog_events).once

          @adapter.start_streaming { |_event| nil }
        end

        def test_start_streaming_handles_errors
          mock_connection
          @adapter.stubs(:ensure_setup)
          @adapter.stubs(:fetch_current_position)
          @adapter.stubs(:stream_binlog_events).raises(StandardError.new('Connection lost'))

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.start_streaming { |_event| nil }
          end

          assert_includes error.message, 'Failed to stream changes'
        end

        def test_stop_streaming
          mock_connection
          @adapter.expects(:close_connection).once
          @adapter.stop_streaming
        end

        def test_current_position_with_cached_values
          @adapter.instance_variable_set(:@binlog_file, 'mysql-bin.000001')
          @adapter.instance_variable_set(:@binlog_position, 12_345)

          assert_equal 'mysql-bin.000001:12345', @adapter.current_position
        end

        def test_current_position_fetches_when_not_cached
          mock_connection

          result_mock = mock('result')
          result_mock.stubs(:first).returns({
            'File' => 'mysql-bin.000002',
            'Position' => '67890',
          })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).with('SHOW MASTER STATUS').returns(result_mock)

          result = @adapter.current_position

          assert_equal 'mysql-bin.000002:67890', result
        end

        def test_setup_validates_configuration
          mock_connection
          @adapter.expects(:validate_binlog_format).once
          @adapter.expects(:validate_server_id).once
          @adapter.expects(:enable_binlog_checksum).once

          @adapter.setup
        end

        def test_teardown_closes_connection
          @adapter.stubs(:log)
          @adapter.expects(:close_connection).once
          @adapter.teardown
        end

        def test_test_connection_success
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({
            '@@hostname' => 'test-server',
            '@@version' => '8.0.25',
            '@@server_id' => '1',
          })

          connection_mock = mock('connection')
          connection_mock.expects(:query).returns(result_mock)
          connection_mock.stubs(:ping).returns(true)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert @adapter.test_connection
        end

        def test_test_connection_failure
          mock_connection
          connection_mock = mock('connection')
          connection_mock.expects(:query).raises(StandardError.new('Connection failed'))
          connection_mock.stubs(:ping).returns(true)
          @adapter.instance_variable_set(:@connection, connection_mock)

          refute @adapter.test_connection
        end

        def test_parse_database_url
          url = 'mysql://user:pass@localhost:3306/testdb?ssl=true'
          parsed = @adapter.send(:parse_database_url, url)

          assert_equal 'localhost', parsed[:host]
          assert_equal 3306, parsed[:port]
          assert_equal 'user', parsed[:username]
          assert_equal 'pass', parsed[:password]
          assert_equal 'testdb', parsed[:database]
          assert parsed[:ssl]
        end

        def test_parse_database_url_minimal
          url = 'mysql://localhost/testdb'
          parsed = @adapter.send(:parse_database_url, url)

          assert_equal 'localhost', parsed[:host]
          assert_nil parsed[:port]
          assert_nil parsed[:username]
          assert_nil parsed[:password]
          assert_equal 'testdb', parsed[:database]
          refute parsed[:ssl]
        end

        def test_validate_binlog_format_row
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ '@@binlog_format' => 'ROW' })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).returns(result_mock)

          @adapter.send(:validate_binlog_format)
        end

        def test_validate_binlog_format_mixed
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ '@@binlog_format' => 'MIXED' })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).returns(result_mock)

          @adapter.send(:validate_binlog_format)
        end

        def test_validate_binlog_format_invalid
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ '@@binlog_format' => 'STATEMENT' })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).returns(result_mock)

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.send(:validate_binlog_format)
          end

          assert_includes error.message, 'Binary log format must be ROW or MIXED'
        end

        def test_validate_server_id_success
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ '@@server_id' => '100' })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).returns(result_mock)

          @adapter.send(:validate_server_id)
        end

        def test_validate_server_id_conflict
          mock_connection
          @adapter.instance_variable_set(:@server_id, 1001)
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ '@@server_id' => 1001 })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).returns(result_mock)

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.send(:validate_server_id)
          end

          assert_includes error.message, 'Server ID conflict'
        end

        def test_enable_binlog_checksum
          mock_connection
          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).with('SET @master_binlog_checksum = @@global.binlog_checksum')

          @adapter.send(:enable_binlog_checksum)
        end

        def test_fetch_current_position_success
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({
            'File' => 'mysql-bin.000003',
            'Position' => '154',
          })

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).with('SHOW MASTER STATUS').returns(result_mock)

          @adapter.send(:fetch_current_position)

          assert_equal 'mysql-bin.000003', @adapter.binlog_file
          assert_equal '154', @adapter.binlog_position
        end

        def test_fetch_current_position_no_status
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns(nil)

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:query).with('SHOW MASTER STATUS').returns(result_mock)

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.send(:fetch_current_position)
          end

          assert_includes error.message, 'Unable to fetch master status'
        end

        def test_establish_connection_with_ping_success
          existing_connection = mock('existing_connection')
          existing_connection.expects(:ping).returns(true)
          @adapter.instance_variable_set(:@connection, existing_connection)

          @adapter.send(:establish_connection)

          assert_equal existing_connection, @adapter.connection
        end

        def test_establish_connection_creates_new
          @adapter.instance_variable_set(:@database_url, 'mysql://user:pass@localhost:3306/testdb')
          @adapter.stubs(:log)

          mock_trilogy_connection = mock('trilogy_connection')
          Trilogy.expects(:new).with(
            host: 'localhost',
            port: 3306,
            username: 'user',
            password: 'pass',
            database: 'testdb',
            ssl: nil,
          ).returns(mock_trilogy_connection)

          @adapter.send(:establish_connection)

          assert_equal mock_trilogy_connection, @adapter.connection
        end

        def test_establish_connection_handles_error
          @adapter.instance_variable_set(:@database_url, 'mysql://localhost/testdb')
          @adapter.stubs(:log)

          Trilogy.expects(:new).raises(StandardError.new('Connection failed'))

          error = assert_raises Whodunit::Chronicles::AdapterError do
            @adapter.send(:establish_connection)
          end

          assert_includes error.message, 'Connection failed'
        end

        def test_close_connection
          mock_connection = mock('connection')
          mock_connection.expects(:close)
          @adapter.instance_variable_set(:@connection, mock_connection)

          @adapter.send(:close_connection)

          assert_nil @adapter.connection
        end

        def test_register_replica_server
          @adapter.instance_variable_set(:@server_id, 1001)
          @adapter.stubs(:log)

          # This is a placeholder test since register_replica_server is not fully implemented
          @adapter.send(:register_replica_server)
        end

        def test_request_binlog_dump
          @adapter.instance_variable_set(:@binlog_file, 'mysql-bin.000001')
          @adapter.instance_variable_set(:@binlog_position, 12_345)
          @adapter.stubs(:log)

          # This is a placeholder test since request_binlog_dump is not fully implemented
          @adapter.send(:request_binlog_dump)
        end

        def test_process_binlog_stream_yields_placeholder_event
          @adapter.stubs(:log)
          @adapter.stubs(:current_position).returns('mysql-bin.000001:12345')
          events_received = []

          @adapter.send(:process_binlog_stream) do |event|
            events_received << event
          end

          assert_equal 1, events_received.size
          event = events_received.first

          assert_equal 'example_table', event.table_name
          assert_equal 'INSERT', event.action
          assert_equal({ id: 1, name: 'test' }, event.new_data)
        end

        private

        def mock_connection
          @adapter.stubs(:establish_connection)

          # Mock the connection instance variable
          mock_conn = mock('connection')
          mock_conn.stubs(:query).returns(mock_result = mock('result'))
          mock_conn.stubs(:close)
          mock_conn.stubs(:ping).returns(true)
          mock_result.stubs(:first).returns({})
          @adapter.instance_variable_set(:@connection, mock_conn)

          # Stub log method
          @adapter.stubs(:log)
        end
      end
    end
  end
end
