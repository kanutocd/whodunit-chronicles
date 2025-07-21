# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    class StreamAdapterTest < Minitest::Test
      def setup
        super
        @adapter = Whodunit::Chronicles::StreamAdapter.new(logger: mock_logger)
      end

      def test_initialization
        refute_predicate @adapter, :streaming?
        # Don't test current_position here as it's abstract
      end

      def test_start_streaming_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.start_streaming { |_event| nil }
        end
      end

      def test_stop_streaming_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.stop_streaming
        end
      end

      def test_current_position_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.current_position
        end
      end

      def test_setup_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.setup
        end
      end

      def test_teardown_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.teardown
        end
      end

      def test_test_connection_raises_not_implemented
        assert_raises NotImplementedError do
          @adapter.test_connection
        end
      end

      def test_streaming_status
        refute_predicate @adapter, :streaming?

        # Test protected setter through send
        @adapter.send(:running=, true)

        assert_predicate @adapter, :streaming?

        @adapter.send(:running=, false)

        refute_predicate @adapter, :streaming?
      end

      def test_position_tracking
        # Test protected setter through send
        @adapter.send(:position=, '0/1234ABCD')
        # Since current_position is abstract, this will still raise NotImplementedError
        assert_raises NotImplementedError do
          @adapter.current_position
        end
      end
    end
  end
end
