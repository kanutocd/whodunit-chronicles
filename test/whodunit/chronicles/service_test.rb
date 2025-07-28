# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    class ServiceTest < Minitest::Test
      def setup
        super
        @mock_adapter = mock('adapter')
        @mock_processor = mock('processor')
        @service = Service.new(
          adapter: @mock_adapter,
          processor: @mock_processor,
          logger: mock_logger,
        )
      end

      def test_initialization_with_defaults
        service = Service.new(logger: mock_logger)

        assert_instance_of Service, service
      end

      def test_initialization_with_custom_adapter_and_processor
        assert_same @mock_adapter, @service.adapter
        assert_same @mock_processor, @service.processor
      end

      def test_start_validates_setup_and_starts_streaming
        @service.expects(:validate_setup!).once
        @service.expects(:test_connections!).once
        @service.expects(:start_streaming_with_retry).once

        result = @service.start

        assert_same @service, result
        assert_predicate @service, :running?
      end

      def test_start_handles_setup_errors
        @service.expects(:validate_setup!).raises(ConfigurationError.new('Invalid config'))

        assert_raises ConfigurationError do
          @service.start
        end

        refute_predicate @service, :running?
      end

      def test_start_returns_early_if_already_running
        @service.instance_variable_set(:@running, true)

        result = @service.start

        assert_same @service, result
      end

      def test_stop_when_running
        @service.instance_variable_set(:@running, true)
        @mock_adapter.expects(:streaming?).returns(true)
        @mock_adapter.expects(:stop_streaming).once
        @mock_processor.expects(:close).once

        executor_mock = mock('executor')
        executor_mock.expects(:shutdown).once
        executor_mock.expects(:wait_for_termination).with(timeout: 30).once
        @service.instance_variable_set(:@executor, executor_mock)

        @service.stop

        refute_predicate @service, :running?
      end

      def test_stop_when_not_running
        refute_predicate @service, :running?

        @service.stop # Should not raise any errors
      end

      def test_running_status
        refute_predicate @service, :running?

        @service.instance_variable_set(:@running, true)

        assert_predicate @service, :running?
      end

      def test_status_information
        @service.instance_variable_set(:@running, true)
        @service.instance_variable_set(:@retry_count, 2)
        @mock_adapter.expects(:streaming?).returns(true)
        @mock_adapter.expects(:current_position).returns('0/ABCDEF')

        executor_mock = mock('executor')
        executor_mock.expects(:active_count).returns(1)
        executor_mock.expects(:completed_task_count).returns(10)
        executor_mock.expects(:queue_length).returns(5)
        @service.instance_variable_set(:@executor, executor_mock)

        status = @service.status

        assert status[:running]
        assert status[:adapter_streaming]
        assert_equal '0/ABCDEF', status[:adapter_position]
        assert_equal 2, status[:retry_count]
        assert_equal 1, status[:executor_status][:active_count]
      end

      def test_setup_calls_adapter_setup
        @mock_adapter.expects(:setup).once

        @service.setup!
      end

      def test_teardown_stops_and_calls_adapter_teardown
        @service.instance_variable_set(:@running, true) # Set running to trigger stop
        @service.expects(:stop).once
        @mock_adapter.expects(:teardown).once

        @service.teardown!
      end

      def test_build_adapter_postgresql
        service = Service.new(logger: mock_logger)

        adapter = service.send(:build_adapter)

        assert_instance_of Adapters::PostgreSQL, adapter
      end

      def test_build_adapter_mysql
        Chronicles.configure { |config| config.adapter = :mysql }
        service = Service.new(logger: mock_logger)

        adapter = service.send(:build_adapter)

        assert_instance_of Adapters::MySQL, adapter
      ensure
        Chronicles.configure { |config| config.adapter = :postgresql }
      end

      def test_build_adapter_unsupported
        Chronicles.configure { |config| config.adapter = :oracle }

        error = assert_raises ConfigurationError do
          Service.new(logger: mock_logger)
        end

        assert_includes error.message, 'Unsupported adapter'
      ensure
        Chronicles.configure { |config| config.adapter = :postgresql }
      end

      def test_validate_setup_calls_config_validate
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:validate!).once
        @mock_adapter.expects(:test_connection).returns(true)

        @service.send(:validate_setup!)
      end

      def test_validate_setup_raises_on_connection_failure
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:validate!).once
        @mock_adapter.expects(:test_connection).returns(false)

        error = assert_raises AdapterError do
          @service.send(:validate_setup!)
        end

        assert_includes error.message, 'Failed to connect'
      end

      def test_test_connections_success
        @mock_adapter.expects(:test_connection).returns(true)
        @mock_processor.expects(:send).with(:ensure_connection).once

        @service.send(:test_connections!)
      end

      def test_test_connections_failure
        @mock_adapter.expects(:test_connection).returns(true)
        @mock_processor.expects(:send).raises(StandardError.new('Connection failed'))

        error = assert_raises AdapterError do
          @service.send(:test_connections!)
        end

        assert_includes error.message, 'Connection test failed'
      end

      def test_process_change_event_success
        change_event = create_change_event(action: 'INSERT')
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:chronicle_table?).with('users', 'public').returns(true)
        @mock_processor.expects(:process).with(change_event).once

        @service.send(:process_change_event, change_event)
      end

      def test_process_change_event_filtered_out
        change_event = create_change_event(action: 'INSERT')
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:chronicle_table?).with('users', 'public').returns(false)
        @mock_processor.expects(:process).never

        @service.send(:process_change_event, change_event)
      end

      def test_process_change_event_with_nil_event
        @mock_processor.expects(:process).never

        @service.send(:process_change_event, nil)
      end

      def test_process_change_event_handles_errors
        change_event = create_change_event(action: 'INSERT')
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:chronicle_table?).returns(true)
        @mock_processor.expects(:process).raises(StandardError.new('Processing failed'))

        # Should not raise, just log error
        @service.send(:process_change_event, change_event)
      end

      def test_should_chronicle_table
        change_event = create_change_event(action: 'INSERT')
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:chronicle_table?).with('users', 'public').returns(true)

        assert @service.send(:should_chronicle_table?, change_event)
      end

      def test_handle_streaming_error
        error = StandardError.new('Streaming failed')
        Chronicles.expects(:config).returns(mock_config = mock('config')).twice
        mock_config.expects(:max_retry_attempts).returns(3)
        mock_config.expects(:retry_delay).returns(1)
        @service.expects(:should_retry?).returns(true)
        @service.expects(:sleep).with(1).once

        @service.send(:handle_streaming_error, error)

        assert_equal 1, @service.instance_variable_get(:@retry_count)
      end

      def test_should_retry_when_running_and_under_limit
        @service.instance_variable_set(:@running, true)
        @service.instance_variable_set(:@retry_count, 1)
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:max_retry_attempts).returns(3)

        assert @service.send(:should_retry?)
      end

      def test_should_retry_when_not_running
        @service.instance_variable_set(:@running, false)

        refute @service.send(:should_retry?)
      end

      def test_should_retry_when_over_limit
        @service.instance_variable_set(:@running, true)
        @service.instance_variable_set(:@retry_count, 5)
        Chronicles.expects(:config).returns(mock_config = mock('config'))
        mock_config.expects(:max_retry_attempts).returns(3)

        refute @service.send(:should_retry?)
      end

      def test_start_streaming_with_retry_loops_while_running
        @service.instance_variable_set(:@running, false) # Will break loop immediately
        executor_mock = mock('executor')
        executor_mock.expects(:post).yields
        @service.instance_variable_set(:@executor, executor_mock)

        @service.send(:start_streaming_with_retry)
      end
    end
  end
end
