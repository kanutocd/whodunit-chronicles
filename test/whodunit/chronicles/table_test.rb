# frozen_string_literal: true

require 'test_helper'

class TableTest < Minitest::Test
  def setup
    super
    @test_class = Class.new do
      include Whodunit::Chronicles::Table

      attr_accessor :connection, :audit_database_url

      def initialize
        @connection = nil
        @audit_database_url = nil
      end

      # Make private methods public for testing
      public :ensure_table_exists, :create_postgresql_table, :create_mysql_table

      # Add detect_database_type method for testing
      def detect_database_type(url)
        return :postgresql if url&.include?('postgres')
        return :mysql if url&.include?('mysql')

        :postgresql # default
      end
    end

    @instance = @test_class.new
  end

  def test_ensure_table_exists_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    mock_connection.expects(:exec).once

    @instance.ensure_table_exists
  end

  def test_ensure_table_exists_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    mock_connection.expects(:query).once

    @instance.ensure_table_exists
  end

  def test_ensure_table_exists_uses_default_config_url
    Whodunit::Chronicles.config.database_url = 'postgres://default:pass@localhost/db'
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    mock_connection.expects(:exec).once

    @instance.ensure_table_exists
  end

  def test_create_postgresql_table_success
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    # Just test that exec is called with some SQL containing key elements
    mock_connection.expects(:exec).once.with do |sql|
      sql.is_a?(String) &&
      sql.include?('CREATE TABLE IF NOT EXISTS whodunit_chronicles_audits') &&
      sql.include?('id BIGSERIAL PRIMARY KEY') &&
      sql.include?('record_id JSONB') &&
      sql.include?('CONSTRAINT valid_data_for_action') &&
      sql.include?('CREATE INDEX CONCURRENTLY')
    end

    @instance.create_postgresql_table
  end

  def test_create_postgresql_table_handles_already_exists_error
    skip "PG::Error mocking is complex - functionality tested in integration"
    # This functionality is covered by integration tests where real PG::Error is available
  end

  def test_create_postgresql_table_raises_other_pg_errors
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    pg_error = Class.new(StandardError) do
      def message
        'connection lost'
      end
    end

    # Stub PG::Error constant if it doesn't exist
    unless defined?(PG::Error)
      Object.const_set(:PG, Module.new) unless defined?(PG)
      PG.const_set(:Error, pg_error) unless defined?(PG::Error)
    end

    mock_connection.expects(:exec).raises(pg_error.new)

    assert_raises(pg_error) { @instance.create_postgresql_table }
  end

  def test_create_mysql_table_success
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    # Just test that query is called with some SQL containing key elements
    mock_connection.expects(:query).once.with do |sql|
      sql.is_a?(String) &&
      sql.include?('CREATE TABLE IF NOT EXISTS whodunit_chronicles_audits') &&
      sql.include?('id BIGINT AUTO_INCREMENT PRIMARY KEY') &&
      sql.include?('record_id JSON') &&
      sql.include?('CONSTRAINT valid_data_for_action') &&
      sql.include?('INDEX idx_chronicles_audits_table_record')
    end

    @instance.create_mysql_table
  end

  def test_create_mysql_table_handles_already_exists_error
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    error = StandardError.new('Table whodunit_chronicles_audits already exists')
    mock_connection.expects(:query).raises(error)

    # Should not raise since error message contains "already exists"
    begin
      @instance.create_mysql_table
    rescue StandardError => e
      flunk "Expected no exception, but got: #{e.message}"
    end
  end

  def test_create_mysql_table_handles_table_already_exists_error
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    error = StandardError.new('Table \'whodunit_chronicles_audits\' already exists')
    mock_connection.expects(:query).raises(error)

    # Should not raise since error message contains "Table" and "already exists"
    begin
      @instance.create_mysql_table
    rescue StandardError => e
      flunk "Expected no exception, but got: #{e.message}"
    end
  end

  def test_create_mysql_table_raises_other_errors
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    error = StandardError.new('connection lost')
    mock_connection.expects(:query).raises(error)

    assert_raises(StandardError) { @instance.create_mysql_table }
  end
end
