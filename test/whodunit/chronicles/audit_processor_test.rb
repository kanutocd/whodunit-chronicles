# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    class AuditProcessorTest < Minitest::Test
      def setup
        super
        @processor = AuditProcessor.new(logger: mock_logger)
      end

      def test_initialization_with_defaults
        processor = AuditProcessor.new(logger: mock_logger)

        assert_instance_of AuditProcessor, processor
      end

      def test_initialization_with_custom_audit_database_url
        processor = AuditProcessor.new(
          audit_database_url: 'postgresql://localhost/audit',
          logger: mock_logger,
        )

        assert_instance_of AuditProcessor, processor
      end

      def test_process_creates_audit_record
        change_event = create_change_event(action: 'INSERT')
        mock_audit_connection

        audit_record = @processor.process(change_event)

        assert audit_record[:id]
        assert_equal 'users', audit_record[:table_name]
        assert_equal 'INSERT', audit_record[:action]
        assert_equal change_event.new_data, audit_record[:new_data]
      end

      def test_process_handles_errors
        change_event = create_change_event(action: 'INSERT')
        @processor.stubs(:ensure_audit_connection).raises(StandardError.new('Connection failed'))

        assert_raises StandardError do
          @processor.process(change_event)
        end
      end

      def test_process_batch_with_empty_array
        result = @processor.process_batch([])

        assert_empty result
      end

      def test_process_batch_with_events
        events = [
          create_change_event(action: 'INSERT'),
          create_change_event(action: 'UPDATE'),
        ]

        # Mock the database connection to prevent real DB access
        @processor.stubs(:ensure_audit_connection)
        @processor.expects(:persist_audit_records_batch).returns([
                                                                   { id: 1, action: 'INSERT' },
                                                                   { id: 2, action: 'UPDATE' },
                                                                 ])

        audit_records = @processor.process_batch(events)

        assert_equal 2, audit_records.size
        assert_equal 'INSERT', audit_records[0][:action]
        assert_equal 'UPDATE', audit_records[1][:action]
      end

      def test_process_batch_handles_errors
        events = [create_change_event(action: 'INSERT')]
        @processor.stubs(:ensure_audit_connection).raises(StandardError.new('Batch failed'))

        assert_raises StandardError do
          @processor.process_batch(events)
        end
      end

      def test_close_closes_connection
        mock_connection = mock('connection')
        mock_connection.expects(:close)
        @processor.instance_variable_set(:@audit_connection, mock_connection)

        @processor.close

        assert_nil @processor.instance_variable_get(:@audit_connection)
      end

      def test_build_audit_record_for_insert
        change_event = create_change_event(action: 'INSERT')

        audit_record = @processor.send(:build_audit_record, change_event)

        assert_equal 'users', audit_record[:table_name]
        assert_equal 'public', audit_record[:schema_name]
        assert_equal 'INSERT', audit_record[:action]
        assert_equal change_event.primary_key, audit_record[:record_id]
        assert_nil audit_record[:old_data]
        assert_equal change_event.new_data, audit_record[:new_data]
        assert_instance_of Hash, audit_record[:metadata]
      end

      def test_build_audit_record_for_update
        change_event = create_change_event(action: 'UPDATE')

        audit_record = @processor.send(:build_audit_record, change_event)

        assert_equal 'UPDATE', audit_record[:action]
        assert_equal change_event.old_data, audit_record[:old_data]
        assert_equal change_event.new_data, audit_record[:new_data]
        assert_equal change_event.changes, audit_record[:changes]
      end

      def test_build_audit_record_for_delete
        change_event = create_change_event(action: 'DELETE')

        audit_record = @processor.send(:build_audit_record, change_event)

        assert_equal 'DELETE', audit_record[:action]
        assert_equal change_event.old_data, audit_record[:old_data]
        assert_nil audit_record[:new_data]
      end

      def test_extract_user_info_with_creator_id
        change_event = create_change_event(
          action: 'INSERT',
          new_data: { 'id' => 1, 'name' => 'Ken', 'creator_id' => 42 },
        )

        user_info = @processor.send(:extract_user_info, change_event)

        assert_equal 42, user_info[:user_id]
        assert_equal 'User', user_info[:user_type]
      end

      def test_extract_user_info_with_updater_id
        change_event = create_change_event(
          action: 'UPDATE',
          new_data: { 'id' => 1, 'name' => 'Sophia', 'updater_id' => 99 },
        )

        user_info = @processor.send(:extract_user_info, change_event)

        assert_equal 99, user_info[:user_id]
        assert_equal 'User', user_info[:user_type]
      end

      def test_extract_user_info_with_deleter_id
        change_event = create_change_event(
          action: 'DELETE',
          old_data: { 'id' => 1, 'name' => 'Ken', 'deleter_id' => 123 },
        )

        user_info = @processor.send(:extract_user_info, change_event)

        assert_equal 123, user_info[:user_id]
        assert_equal 'User', user_info[:user_type]
      end

      def test_extract_user_info_without_user_id
        change_event = create_change_event(action: 'INSERT')

        user_info = @processor.send(:extract_user_info, change_event)

        assert_nil user_info[:user_id]
        assert_nil user_info[:user_type]
      end

      def test_build_metadata
        change_event = create_change_event(action: 'UPDATE')

        metadata = @processor.send(:build_metadata, change_event)

        assert_equal 'public', metadata[:table_schema]
        assert_equal 'public.users', metadata[:qualified_table_name]
        assert_equal change_event.changed_columns, metadata[:changed_columns]
        assert_equal change_event.metadata, metadata[:adapter_metadata]
        assert_equal Chronicles::VERSION, metadata[:chronicles_version]
      end

      def test_persist_audit_record
        mock_audit_connection
        audit_record = {
          table_name: 'users',
          schema_name: 'public',
          record_id: { 'id' => 1 },
          action: 'INSERT',
          old_data: nil,
          new_data: { 'id' => 1, 'name' => 'Ken' },
          changes: {},
          user_id: 42,
          user_type: 'User',
          transaction_id: 'tx123',
          sequence_number: 1,
          occurred_at: Time.now,
          created_at: Time.now,
          metadata: { version: '1.0' },
        }

        result = @processor.send(:persist_audit_record, audit_record)

        assert_equal 123, result[:id]
        assert_equal audit_record[:table_name], result[:table_name]
      end

      def test_persist_audit_records_batch_empty
        result = @processor.send(:persist_audit_records_batch, [])

        assert_empty result
      end

      def test_persist_audit_records_batch_with_records
        mock_audit_connection_batch
        audit_records = [
          build_sample_audit_record('INSERT'),
          build_sample_audit_record('UPDATE'),
        ]

        result = @processor.send(:persist_audit_records_batch, audit_records)

        assert_equal 2, result.size
        # Verify that the IDs have been set on the records
        assert_equal 101, audit_records[0][:id]
        assert_equal 102, audit_records[1][:id]
        # The method returns the same array
        assert_same audit_records, result
      end

      def test_ensure_audit_connection_creates_table
        mock_connection = mock('connection')
        mock_connection.expects(:type_map_for_results=)
        mock_connection.expects(:exec).once # For table creation
        PG.expects(:connect).returns(mock_connection)
        PG::BasicTypeMapForResults.expects(:new).returns(mock('type_map'))

        @processor.send(:ensure_audit_connection)
      end

      private

      def mock_audit_connection
        mock_connection = mock('connection')
        mock_connection.stubs(:type_map_for_results=)
        mock_connection.stubs(:exec)
        mock_connection.stubs(:finished?).returns(false)

        # Mock the persist_audit_record SQL execution
        result_mock = mock('result')
        result_mock.stubs(:first).returns({ 'id' => '123' })
        result_mock.expects(:clear)
        mock_connection.stubs(:exec_params).returns(result_mock)

        @processor.instance_variable_set(:@audit_connection, mock_connection)
        @processor.stubs(:ensure_audit_table_exists)
      end

      def mock_audit_connection_batch
        mock_connection = mock('connection')
        mock_connection.stubs(:type_map_for_results=)
        mock_connection.stubs(:exec)
        mock_connection.stubs(:finished?).returns(false)

        # Create a special result mock that actually modifies the audit_records
        result_mock = Object.new
        def result_mock.each_with_index
          # Simulate the database returning IDs
          yield({ 'id' => '101' }, 0)
          yield({ 'id' => '102' }, 1)
        end

        def result_mock.clear
          # Mock clear method
        end
        mock_connection.stubs(:exec_params).returns(result_mock)

        @processor.instance_variable_set(:@audit_connection, mock_connection)
        @processor.stubs(:ensure_audit_table_exists)
      end

      def build_sample_audit_record(action)
        {
          id: nil,
          table_name: 'users',
          schema_name: 'public',
          record_id: { 'id' => 1 },
          action: action,
          old_data: action == 'INSERT' ? nil : { 'id' => 1, 'name' => 'Ken' },
          new_data: action == 'DELETE' ? nil : { 'id' => 1, 'name' => 'Sophia' },
          changes: action == 'UPDATE' ? { 'name' => %w[John Jane] } : {},
          user_id: 42,
          user_type: 'User',
          transaction_id: 'tx123',
          sequence_number: 1,
          occurred_at: Time.now,
          created_at: Time.now,
          metadata: { version: '1.0' },
        }
      end
    end
  end
end
