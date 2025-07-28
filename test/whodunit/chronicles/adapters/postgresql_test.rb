# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    module Adapters
      class PostgreSQLTest < Minitest::Test
        def setup
          super
          @adapter = PostgreSQL.new(
            database_url: 'postgresql://localhost/test',
            logger: mock_logger,
          )
        end

        def test_initialization
          adapter = PostgreSQL.new(logger: mock_logger)

          assert_equal 'whodunit_chronicles', adapter.publication_name
          assert_equal 'whodunit_chronicles_slot', adapter.slot_name
        end

        def test_initialization_with_custom_options
          adapter = PostgreSQL.new(
            database_url: 'postgresql://localhost/custom',
            publication_name: 'custom_pub',
            slot_name: 'custom_slot',
            logger: mock_logger,
          )

          assert_equal 'custom_pub', adapter.publication_name
          assert_equal 'custom_slot', adapter.slot_name
        end

        def test_start_streaming_requires_block
          mock_connection
          @adapter.stubs(:ensure_setup)

          error = assert_raises ArgumentError do
            @adapter.start_streaming
          end

          assert_includes error.message, 'Block required'
        end

        def test_start_streaming_calls_stream_changes
          mock_connection
          @adapter.stubs(:ensure_setup)
          @adapter.stubs(:confirmed_flush_lsn).returns('0/12345')
          @adapter.expects(:stream_changes).once

          @adapter.start_streaming { |_event| nil }
        end

        def test_start_streaming_handles_errors
          mock_connection
          @adapter.stubs(:ensure_setup)
          @adapter.stubs(:confirmed_flush_lsn).returns('0/12345')
          @adapter.stubs(:stream_changes).raises(StandardError.new('Connection lost'))

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.start_streaming { |_event| nil }
          end

          assert_includes error.message, 'Failed to stream changes'
        end

        def test_stop_streaming
          mock_connection # Add connection mock to prevent exec_params calls
          @adapter.expects(:close_connections).once
          @adapter.stop_streaming
        end

        def test_current_position_with_lsn
          @adapter.instance_variable_set(:@last_lsn, '0/ABCDEF')

          assert_equal '0/ABCDEF', @adapter.current_position
        end

        def test_current_position_fallback_to_confirmed_flush
          mock_connection
          @adapter.unstub(:current_position) # Remove the stub for this test
          @adapter.expects(:confirmed_flush_lsn).returns('0/123456')

          assert_equal '0/123456', @adapter.current_position
        end

        def test_setup_creates_publication_and_slot
          mock_connection
          @adapter.expects(:create_publication).once
          @adapter.expects(:create_replication_slot).once

          @adapter.setup
        end

        def test_teardown_drops_slot_and_publication
          mock_connection
          @adapter.expects(:drop_replication_slot).once
          @adapter.expects(:drop_publication).once

          @adapter.teardown
        end

        def test_test_connection_success
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:first).returns({
            'current_database' => 'test_db',
            'current_user' => 'test_user',
            'version' => 'PostgreSQL 15.0',
          })
          result_mock.expects(:clear).once

          connection_mock = mock('connection')
          connection_mock.expects(:exec).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert @adapter.test_connection
        end

        def test_test_connection_failure
          mock_connection
          connection_mock = mock('connection')
          connection_mock.expects(:exec).raises(PG::Error.new('Connection failed'))
          @adapter.instance_variable_set(:@connection, connection_mock)

          refute @adapter.test_connection
        end

        def test_build_copy_statement
          @adapter.instance_variable_set(:@publication_name, 'test_pub')
          @adapter.instance_variable_set(:@slot_name, 'test_slot')

          statement = @adapter.send(:build_copy_statement)

          assert_includes statement, 'test_slot'
          assert_includes statement, 'test_pub'
          assert_includes statement, 'COPY'
        end

        def test_publication_exists_true
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:ntuples).returns(1)
          result_mock.expects(:clear)

          connection_mock = mock('connection')
          connection_mock.expects(:exec_params).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert @adapter.send(:publication_exists?)
        end

        def test_publication_exists_false
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:ntuples).returns(0)
          result_mock.expects(:clear)

          connection_mock = mock('connection')
          connection_mock.expects(:exec_params).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          refute @adapter.send(:publication_exists?)
        end

        def test_replication_slot_exists_true
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:ntuples).returns(1)
          result_mock.expects(:clear)

          connection_mock = mock('connection')
          connection_mock.expects(:exec_params).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert @adapter.send(:replication_slot_exists?)
        end

        def test_create_publication_when_exists
          mock_connection
          @adapter.expects(:publication_exists?).returns(true)

          @adapter.send(:create_publication)
        end

        def test_create_publication_when_not_exists
          mock_connection
          @adapter.expects(:publication_exists?).returns(false)
          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:exec).once

          @adapter.send(:create_publication)
        end

        def test_create_replication_slot_when_exists
          mock_connection
          @adapter.expects(:replication_slot_exists?).returns(true)

          @adapter.send(:create_replication_slot)
        end

        def test_create_replication_slot_when_not_exists
          mock_connection
          @adapter.expects(:replication_slot_exists?).returns(false)
          result_mock = mock('result')
          result_mock.stubs(:first).returns({ 'lsn' => '0/123456' })
          result_mock.expects(:clear)

          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:exec).returns(result_mock)

          @adapter.send(:create_replication_slot)
        end

        def test_drop_publication_when_exists
          mock_connection
          @adapter.expects(:publication_exists?).returns(true)
          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:exec).once

          @adapter.send(:drop_publication)
        end

        def test_drop_replication_slot_when_exists
          mock_connection
          @adapter.expects(:replication_slot_exists?).returns(true)
          connection_mock = @adapter.instance_variable_get(:@connection)
          connection_mock.expects(:exec).once

          @adapter.send(:drop_replication_slot)
        end

        def test_confirmed_flush_lsn_with_slot
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:ntuples).returns(1)
          result_mock.stubs(:first).returns({ 'confirmed_flush_lsn' => '0/ABCDEF' })
          result_mock.expects(:clear)

          connection_mock = mock('connection')
          connection_mock.expects(:exec_params).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert_equal '0/ABCDEF', @adapter.send(:confirmed_flush_lsn)
        end

        def test_confirmed_flush_lsn_without_slot
          mock_connection
          result_mock = mock('result')
          result_mock.stubs(:ntuples).returns(0)
          result_mock.expects(:clear)

          connection_mock = mock('connection')
          connection_mock.expects(:exec_params).returns(result_mock)
          @adapter.instance_variable_set(:@connection, connection_mock)

          assert_nil @adapter.send(:confirmed_flush_lsn)
        end

        def test_parse_logical_message_returns_nil
          result = @adapter.send(:parse_logical_message, '')

          assert_nil result
        end

        def test_parse_logical_message_with_data
          mock_connection # Add connection mock to prevent exec_params calls
          result = @adapter.send(:parse_logical_message, "line1\nline2")

          assert_nil result # Current implementation returns nil
        end

        def test_process_wal_data_with_nil_event
          mock_connection # Add connection mock to prevent exec_params calls

          @adapter.send(:process_wal_data, 'test data') { |event| refute event }
        end

        def test_process_wal_data_handles_errors
          mock_connection # Add connection mock to prevent exec_params calls
          @adapter.stubs(:parse_logical_message).raises(StandardError.new('Parse error'))

          # Should not raise, just log error
          @adapter.send(:process_wal_data, 'invalid data') { |_event| nil }
        end

        def test_establish_connection_when_not_connected
          @adapter.instance_variable_set(:@connection, nil)

          mock_connection = mock('pg_connection')
          mock_connection.stubs(:finished?).returns(false)
          mock_connection.expects(:type_map_for_results=)

          mock_type_map = mock('type_map')

          # Mock PG.connect directly
          PG.expects(:connect).with('postgresql://localhost/test').returns(mock_connection)

          # Mock PG::BasicTypeMapForResults
          PG::BasicTypeMapForResults.expects(:new).with(mock_connection).returns(mock_type_map)

          @adapter.send(:establish_connection)

          assert_equal mock_connection, @adapter.instance_variable_get(:@connection)
        end

        def test_establish_connection_when_connection_finished
          finished_connection = mock('finished_connection')
          finished_connection.expects(:finished?).returns(true)
          @adapter.instance_variable_set(:@connection, finished_connection)

          mock_connection = mock('pg_connection')
          mock_connection.stubs(:finished?).returns(false)
          mock_connection.expects(:type_map_for_results=)

          mock_type_map = mock('type_map')

          # Mock PG.connect directly
          PG.expects(:connect).with('postgresql://localhost/test').returns(mock_connection)

          # Mock PG::BasicTypeMapForResults
          PG::BasicTypeMapForResults.expects(:new).with(mock_connection).returns(mock_type_map)

          @adapter.send(:establish_connection)

          assert_equal mock_connection, @adapter.instance_variable_get(:@connection)
        end

        def test_establish_connection_when_active_connection_exists
          active_connection = mock('active_connection')
          active_connection.expects(:finished?).returns(false)
          @adapter.instance_variable_set(:@connection, active_connection)

          # Should not create new connection
          Object.expects(:const_get).never

          @adapter.send(:establish_connection)

          assert_equal active_connection, @adapter.instance_variable_get(:@connection)
        end

        def test_establish_replication_connection_when_not_connected
          @adapter.instance_variable_set(:@replication_connection, nil)

          mock_repl_connection = mock('replication_connection')
          mock_repl_connection.stubs(:finished?).returns(false)

          # Mock PG.connect directly
          PG.expects(:connect)
            .with('postgresql://localhost/test?replication=database')
            .returns(mock_repl_connection)

          @adapter.send(:establish_replication_connection)

          assert_equal mock_repl_connection, @adapter.instance_variable_get(:@replication_connection)
        end

        def test_establish_replication_connection_when_connection_finished
          finished_connection = mock('finished_replication_connection')
          finished_connection.expects(:finished?).returns(true)
          @adapter.instance_variable_set(:@replication_connection, finished_connection)

          mock_repl_connection = mock('replication_connection')
          mock_repl_connection.stubs(:finished?).returns(false)

          # Mock PG.connect directly
          PG.expects(:connect)
            .with('postgresql://localhost/test?replication=database')
            .returns(mock_repl_connection)

          @adapter.send(:establish_replication_connection)

          assert_equal mock_repl_connection, @adapter.instance_variable_get(:@replication_connection)
        end

        def test_establish_replication_connection_when_active_connection_exists
          active_connection = mock('active_replication_connection')
          active_connection.expects(:finished?).returns(false)
          @adapter.instance_variable_set(:@replication_connection, active_connection)

          # Should not create new connection
          Object.expects(:const_get).never

          @adapter.send(:establish_replication_connection)

          assert_equal active_connection, @adapter.instance_variable_get(:@replication_connection)
        end

        def test_establish_replication_connection_with_existing_query_params
          @adapter.instance_variable_set(:@database_url, 'postgresql://localhost/test?ssl=require')
          @adapter.instance_variable_set(:@replication_connection, nil)

          mock_repl_connection = mock('replication_connection')
          mock_repl_connection.stubs(:finished?).returns(false)

          # Mock PG.connect directly
          PG.expects(:connect)
            .with('postgresql://localhost/test?ssl=require&replication=database')
            .returns(mock_repl_connection)

          @adapter.send(:establish_replication_connection)

          assert_equal mock_repl_connection, @adapter.instance_variable_get(:@replication_connection)
        end

        def test_stream_changes_executes_copy_and_processes_data
          skip 'Complex streaming test requires integration testing with real PostgreSQL connection'
        end

        def test_stream_changes_stops_when_no_more_data
          mock_replication_connection = mock('replication_connection')
          @adapter.instance_variable_set(:@replication_connection, mock_replication_connection)

          # Mock connection for confirmed_flush_lsn calls
          mock_connection = mock('connection')
          mock_result = mock('result')
          mock_result.stubs(:ntuples).returns(0)
          mock_result.stubs(:clear)
          mock_connection.stubs(:exec_params).returns(mock_result)
          @adapter.instance_variable_set(:@connection, mock_connection)

          copy_sql = @adapter.send(:build_copy_statement)
          mock_replication_connection.expects(:exec).with(copy_sql)

          # Return nil immediately to simulate no data
          mock_replication_connection.expects(:get_copy_data).with(async: false).returns(nil)

          @adapter.stubs(:running?).returns(true)

          # Should not call process_wal_data
          @adapter.expects(:process_wal_data).never

          @adapter.send(:stream_changes) { |_event| nil }
        end

        def test_close_connections_closes_both_connections
          mock_connection = mock('connection')
          mock_replication_connection = mock('replication_connection')

          @adapter.instance_variable_set(:@connection, mock_connection)
          @adapter.instance_variable_set(:@replication_connection, mock_replication_connection)

          mock_connection.expects(:close)
          mock_replication_connection.expects(:close)

          @adapter.send(:close_connections)

          assert_nil @adapter.instance_variable_get(:@connection)
          assert_nil @adapter.instance_variable_get(:@replication_connection)
        end

        def test_close_connections_handles_nil_connections
          @adapter.instance_variable_set(:@connection, nil)
          @adapter.instance_variable_set(:@replication_connection, nil)

          # Should not raise any errors
          begin
            @adapter.send(:close_connections)
          rescue StandardError => e
            flunk "Expected no exception, but got: #{e.message}"
          end
        end

        def test_ensure_setup_checks_publication_and_slot
          @adapter.expects(:publication_exists?).returns(true)
          @adapter.expects(:replication_slot_exists?).returns(true)

          @adapter.send(:ensure_setup)
        end

        def test_ensure_setup_raises_when_publication_missing
          @adapter.expects(:publication_exists?).returns(false)

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.send(:ensure_setup)
          end

          assert_includes error.message, 'Publication'
        end

        def test_ensure_setup_raises_when_slot_missing
          @adapter.expects(:publication_exists?).returns(true)
          @adapter.expects(:replication_slot_exists?).returns(false)

          error = assert_raises Whodunit::Chronicles::ReplicationError do
            @adapter.send(:ensure_setup)
          end

          assert_includes error.message, 'Replication slot'
        end

        private

        def mock_connection
          @adapter.stubs(:establish_connection)
          @adapter.stubs(:establish_replication_connection)

          # Mock the connection instance variable to avoid exec_params calls
          mock_conn = mock('connection')
          mock_conn.stubs(:exec_params).returns(mock_result = mock('result'))
          mock_conn.stubs(:close)
          mock_conn.stubs(:finished?).returns(false)
          mock_result.stubs(:ntuples).returns(0)
          mock_result.stubs(:clear)
          mock_result.stubs(:first).returns({})
          @adapter.instance_variable_set(:@connection, mock_conn)

          # Also mock the replication connection
          mock_repl_conn = mock('replication_connection')
          mock_repl_conn.stubs(:close)
          mock_repl_conn.stubs(:finished?).returns(false)
          @adapter.instance_variable_set(:@replication_connection, mock_repl_conn)

          # Stub log method and current_position to avoid confirmed_flush_lsn calls
          @adapter.stubs(:log)
          @adapter.stubs(:current_position).returns('0/123456')
        end
      end
    end
  end
end
