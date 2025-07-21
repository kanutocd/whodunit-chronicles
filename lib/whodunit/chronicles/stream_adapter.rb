# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Abstract base class for database streaming adapters
    #
    # Defines the interface that all database-specific adapters must implement
    # for streaming database changes into audit events.
    class StreamAdapter
      attr_reader :logger

      def initialize(logger: Chronicles.logger)
        @logger = logger
        @running = false
        @position = nil
      end

      # Start streaming database changes
      #
      # @param block [Proc] Block to call for each change event
      # @return [void]
      # @raise [NotImplementedError] Must be implemented by subclasses
      def start_streaming(&)
        raise NotImplementedError, "#{self.class} must implement #start_streaming"
      end

      # Stop streaming database changes
      #
      # @return [void]
      # @raise [NotImplementedError] Must be implemented by subclasses
      def stop_streaming
        raise NotImplementedError, "#{self.class} must implement #stop_streaming"
      end

      # Get current replication position
      #
      # @return [String, nil] Current position or nil if not available
      # @raise [NotImplementedError] Must be implemented by subclasses
      def current_position
        raise NotImplementedError, "#{self.class} must implement #current_position"
      end

      # Check if adapter is currently streaming
      #
      # @return [Boolean]
      def streaming?
        @running
      end

      # Set up the database for streaming (create publications, slots, etc.)
      #
      # @return [void]
      # @raise [NotImplementedError] Must be implemented by subclasses
      def setup
        raise NotImplementedError, "#{self.class} must implement #setup"
      end

      # Tear down streaming setup (remove publications, slots, etc.)
      #
      # @return [void]
      # @raise [NotImplementedError] Must be implemented by subclasses
      def teardown
        raise NotImplementedError, "#{self.class} must implement #teardown"
      end

      # Test connection to the database
      #
      # @return [Boolean] true if connection is successful
      # @raise [NotImplementedError] Must be implemented by subclasses
      def test_connection
        raise NotImplementedError, "#{self.class} must implement #test_connection"
      end

      protected

      attr_writer :running, :position

      # Log a message with context
      #
      # @param level [Symbol] Log level (:info, :warn, :error, etc.)
      # @param message [String] Log message
      # @param context [Hash] Additional context
      def log(level, message, context = {})
        logger.public_send(level, message,
          adapter: self.class.name.split('::').last,
          position: current_position,
          **context)
      end
    end
  end
end
