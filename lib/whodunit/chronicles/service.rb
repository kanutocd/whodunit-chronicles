# frozen_string_literal: true

require 'concurrent-ruby'

module Whodunit
  module Chronicles
    # Main service orchestrator for chronicle streaming
    #
    # Coordinates the stream adapter and processor to provide
    # a complete chronicle streaming solution with error handling and monitoring.
    class Service
      attr_reader :adapter, :processor, :logger, :executor

      def initialize(
        adapter: nil,
        processor: nil,
        logger: Chronicles.logger
      )
        @adapter = adapter || build_adapter
        @processor = processor || Processor.new(logger: logger)
        @logger = logger
        @executor = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: 4,
          max_queue: 100,
          fallback_policy: :caller_runs,
        )
        @running = false
        @retry_count = 0
      end

      # Start the chronicle streaming service
      #
      # @return [self]
      def start
        return self if running?

        log(:info, 'Starting Chronicles streaming service')

        validate_setup!
        test_connections!

        @running = true
        @retry_count = 0

        start_streaming_with_retry

        log(:info, 'Chronicles streaming service started successfully')
        self
      rescue StandardError => e
        log(:error, 'Failed to start service', error: e.message)
        @running = false
        raise
      end

      # Stop the chronicle streaming service
      #
      # @return [void]
      def stop
        return unless running?

        log(:info, 'Stopping Chronicles streaming service')
        @running = false

        adapter.stop_streaming if adapter.streaming?
        @executor.shutdown
        @executor.wait_for_termination(timeout: 30)

        processor.close
        log(:info, 'Chronicles streaming service stopped')
      end

      # Check if service is running
      #
      # @return [Boolean]
      def running?
        @running
      end

      # Get service status information
      #
      # @return [Hash]
      def status
        {
          running: running?,
          adapter_streaming: adapter.streaming?,
          adapter_position: adapter.current_position,
          retry_count: @retry_count,
          executor_status: {
            active_count: @executor.active_count,
            completed_task_count: @executor.completed_task_count,
            queue_length: @executor.queue_length,
          },
        }
      end

      # Set up the chronicle streaming infrastructure
      #
      # @return [void]
      def setup!
        log(:info, 'Setting up chronicle streaming infrastructure')
        adapter.setup
        log(:info, 'Chronicle streaming infrastructure setup completed')
      end

      # Tear down the chronicle streaming infrastructure
      #
      # @return [void]
      def teardown!
        log(:info, 'Tearing down chronicle streaming infrastructure')
        stop if running?
        adapter.teardown
        log(:info, 'Chronicle streaming infrastructure teardown completed')
      end

      private

      def build_adapter
        case Chronicles.config.adapter
        when :postgresql
          Adapters::PostgreSQL.new(logger: logger)
        when :mysql
          Adapters::MySQL.new(logger: logger)
        else
          raise ConfigurationError, "Unsupported adapter: #{Chronicles.config.adapter}"
        end
      end

      def validate_setup!
        Chronicles.config.validate!

        return if adapter.test_connection

        raise AdapterError, 'Failed to connect to source database'
      end

      def test_connections!
        adapter.test_connection
        # Test processor connection by creating a dummy connection
        processor.send(:ensure_connection)
      rescue StandardError => e
        raise AdapterError, "Connection test failed: #{e.message}"
      end

      def start_streaming_with_retry
        @executor.post do
          loop do
            break unless running?

            begin
              adapter.start_streaming do |change_event|
                process_change_event(change_event)
              end
            rescue StandardError => e
              handle_streaming_error(e)
              break unless should_retry?
            end
          end
        end
      end

      def process_change_event(change_event)
        return unless change_event
        return unless should_chronicle_table?(change_event)

        log(:debug, 'Processing change event',
          table: change_event.qualified_table_name,
          action: change_event.action
        )

        processor.process(change_event)
      rescue StandardError => e
        log(:error, 'Failed to process change event',
          error: e.message,
          event: change_event.to_s
        )
      end

      def should_chronicle_table?(change_event)
        Chronicles.config.chronicle_table?(
          change_event.table_name,
          change_event.schema_name,
        )
      end

      def handle_streaming_error(error)
        @retry_count += 1
        log(:error, 'Streaming error occurred',
          error: error.message,
          retry_count: @retry_count,
          max_retries: Chronicles.config.max_retry_attempts
        )

        # Wait before retry
        sleep(Chronicles.config.retry_delay) if should_retry?
      end

      def should_retry?
        running? && @retry_count < Chronicles.config.max_retry_attempts
      end

      def log(level, message, context = {})
        logger.public_send(level, message, service: 'Chronicles::Service', **context)
      end
    end
  end
end
