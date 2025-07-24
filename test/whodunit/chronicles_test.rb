# frozen_string_literal: true

require 'test_helper'

module Whodunit
  class ChroniclesTest < Minitest::Test
    def test_module_exists
      assert defined?(Whodunit::Chronicles)
    end

    def test_version_defined
      refute_nil Whodunit::Chronicles::VERSION
      assert_match(/\A\d+\.\d+\.\d+/, Whodunit::Chronicles::VERSION)
    end

    def test_configuration_access
      config = Whodunit::Chronicles.config

      assert_instance_of Dry::Configurable::Config, config
    end

    def test_configure_block
      original_batch_size = Whodunit::Chronicles.config.batch_size

      Whodunit::Chronicles.configure do |config|
        config.batch_size = 50
      end

      assert_equal 50, Whodunit::Chronicles.config.batch_size
    ensure
      Whodunit::Chronicles.config.batch_size = original_batch_size
    end

    def test_logger_access
      logger = Whodunit::Chronicles.logger

      refute_nil logger
    end

    def test_error_classes_defined
      assert defined?(Whodunit::Chronicles::Error)
      assert defined?(Whodunit::Chronicles::ConfigurationError)
      assert defined?(Whodunit::Chronicles::AdapterError)
      assert defined?(Whodunit::Chronicles::ReplicationError)

      # Test inheritance
      assert_operator Whodunit::Chronicles::ConfigurationError, :<, Whodunit::Chronicles::Error
      assert_operator Whodunit::Chronicles::AdapterError, :<, Whodunit::Chronicles::Error
      assert_operator Whodunit::Chronicles::ReplicationError, :<, Whodunit::Chronicles::Error
    end

    def test_main_classes_defined
      assert defined?(Whodunit::Chronicles::ChangeEvent)
      assert defined?(Whodunit::Chronicles::StreamAdapter)
      assert defined?(Whodunit::Chronicles::Processor)
      assert defined?(Whodunit::Chronicles::Service)
      assert defined?(Whodunit::Chronicles::Configuration)
      assert defined?(Whodunit::Chronicles::Adapters::PostgreSQL)
      assert defined?(Whodunit::Chronicles::Adapters::MySQL)
    end

    def test_start_creates_service
      # Mock the service to avoid actual database connections
      service_mock = Object.new
      def service_mock.start
        self
      end

      Whodunit::Chronicles::Service.stub(:new, service_mock) do
        result = Whodunit::Chronicles.start

        assert_same service_mock, result
      end
    end
  end
end
