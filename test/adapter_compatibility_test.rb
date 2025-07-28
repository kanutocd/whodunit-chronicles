#!/usr/bin/env ruby
# frozen_string_literal: true

# Adapter Compatibility Test Script
# This script validates that both PostgreSQL and MySQL adapters work correctly

require_relative 'test_helper'

class AdapterCompatibilityTest < Minitest::Test
  def test_postgresql_adapter_available
    assert defined?(Whodunit::Chronicles::Adapters::PostgreSQL)

    adapter = Whodunit::Chronicles::Adapters::PostgreSQL.new(logger: mock_logger)

    assert_instance_of Whodunit::Chronicles::Adapters::PostgreSQL, adapter
    assert_respond_to adapter, :start_streaming
    assert_respond_to adapter, :stop_streaming
    assert_respond_to adapter, :setup
    assert_respond_to adapter, :teardown
    assert_respond_to adapter, :test_connection
  end

  def test_mysql_adapter_available
    assert defined?(Whodunit::Chronicles::Adapters::MySQL)

    adapter = Whodunit::Chronicles::Adapters::MySQL.new(logger: mock_logger)

    assert_instance_of Whodunit::Chronicles::Adapters::MySQL, adapter
    assert_respond_to adapter, :start_streaming
    assert_respond_to adapter, :stop_streaming
    assert_respond_to adapter, :setup
    assert_respond_to adapter, :teardown
    assert_respond_to adapter, :test_connection
  end

  def test_service_builds_postgresql_adapter
    Whodunit::Chronicles.configure { |config| config.adapter = :postgresql }
    service = Whodunit::Chronicles::Service.new(logger: mock_logger)

    adapter = service.send(:build_adapter)

    assert_instance_of Whodunit::Chronicles::Adapters::PostgreSQL, adapter
  end

  def test_service_builds_mysql_adapter
    Whodunit::Chronicles.configure { |config| config.adapter = :mysql }
    service = Whodunit::Chronicles::Service.new(logger: mock_logger)

    adapter = service.send(:build_adapter)

    assert_instance_of Whodunit::Chronicles::Adapters::MySQL, adapter
  ensure
    Whodunit::Chronicles.configure { |config| config.adapter = :postgresql }
  end

  def test_configuration_validates_both_adapters
    # Test PostgreSQL validation
    config = Whodunit::Chronicles::Configuration.new
    config.database_url = 'postgresql://localhost/test'
    config.adapter = :postgresql
    # Should not raise
    config.validate!

    # Test MySQL validation
    config.database_url = 'mysql://localhost/test'
    config.adapter = :mysql
    # Should not raise
    config.validate!
  end

  def test_audit_processor_detects_database_types
    processor = Whodunit::Chronicles::Processor.new(logger: mock_logger)

    # Test PostgreSQL URL detection
    pg_type = processor.send(:detect_database_type, 'postgresql://localhost/test')

    assert_equal :postgresql, pg_type

    # Test MySQL URL detection
    mysql_type = processor.send(:detect_database_type, 'mysql://localhost/test')

    assert_equal :mysql, mysql_type

    # Test fallback to config
    nil_type = processor.send(:detect_database_type, nil)

    assert_includes %i[postgresql mysql], nil_type
  end
end
