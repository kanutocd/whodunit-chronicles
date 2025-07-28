# frozen_string_literal: true

require 'test_helper'

class ConnectionTest < Minitest::Test
  def setup
    super
    @test_class = Class.new do
      include Whodunit::Chronicles::Connection

      attr_accessor :connection, :audit_database_url

      def initialize
        @connection = nil
        @audit_database_url = nil
      end

      # Make private methods public for testing
      public :create_connection, :detect_database_type, :parse_mysql_url,
        :connection_active?, :setup_connection_specifics, :ensure_connection

      # Add ensure_table_exists method for testing
      def ensure_table_exists
        # Mock implementation for testing
      end
    end

    @instance = @test_class.new
  end

  def test_detect_database_type_with_postgresql_urls
    assert_equal :postgresql, @instance.detect_database_type('postgres://user:pass@localhost/db')
    assert_equal :postgresql, @instance.detect_database_type('postgresql://user:pass@localhost/db')
  end

  def test_detect_database_type_with_mysql_urls
    assert_equal :mysql, @instance.detect_database_type('mysql://user:pass@localhost/db')
    assert_equal :mysql, @instance.detect_database_type('mysql2://user:pass@localhost/db')
  end

  def test_detect_database_type_with_nil_url_uses_config
    Whodunit::Chronicles.config.adapter = :mysql

    assert_equal :mysql, @instance.detect_database_type(nil)

    Whodunit::Chronicles.config.adapter = :postgresql

    assert_equal :postgresql, @instance.detect_database_type(nil)
  end

  def test_detect_database_type_with_unknown_url_uses_config
    Whodunit::Chronicles.config.adapter = :postgresql

    assert_equal :postgresql, @instance.detect_database_type('unknown://localhost/db')
  end

  def test_parse_mysql_url_full_url
    url = 'mysql://username:password@localhost:3307/database_name?ssl=true'
    result = @instance.parse_mysql_url(url)

    expected = {
      host: 'localhost',
      port: 3307,
      username: 'username',
      password: 'password',
      database: 'database_name',
      ssl: true,
    }

    assert_equal expected, result
  end

  def test_parse_mysql_url_minimal_url
    url = 'mysql://localhost/db'
    result = @instance.parse_mysql_url(url)

    expected = {
      host: 'localhost',
      port: nil,
      username: nil,
      password: nil,
      database: 'db',
      ssl: nil,
    }

    assert_equal expected, result
  end

  def test_parse_mysql_url_no_ssl
    url = 'mysql://user:pass@localhost/db?timeout=30'
    result = @instance.parse_mysql_url(url)

    refute result[:ssl]
  end

  def test_parse_mysql_url_empty_database_path
    url = 'mysql://user:pass@localhost/'
    result = @instance.parse_mysql_url(url)

    assert_equal '', result[:database]
  end

  def test_create_connection_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'

    mock_connection = mock('pg_connection')

    Object.stubs(:require).with('pg')
    PG.expects(:connect).with('postgres://user:pass@localhost/db').returns(mock_connection)

    result = @instance.create_connection

    assert_equal mock_connection, result
  end

  def test_create_connection_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost:3307/db?ssl=true'

    mock_connection = mock('trilogy_connection')

    Object.stubs(:require).with('trilogy')
    Trilogy.expects(:new).with(
      host: 'localhost',
      port: 3307,
      username: 'user',
      password: 'pass',
      database: 'db',
      ssl: true,
    ).returns(mock_connection)

    result = @instance.create_connection

    assert_equal mock_connection, result
  end

  def test_create_connection_mysql_default_port
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'

    mock_connection = mock('trilogy_connection')

    Object.stubs(:require).with('trilogy')
    Trilogy.expects(:new).with(
      host: 'localhost',
      port: 3306, # default port
      username: 'user',
      password: 'pass',
      database: 'db',
      ssl: nil,
    ).returns(mock_connection)

    result = @instance.create_connection

    assert_equal mock_connection, result
  end

  def test_create_connection_uses_config_database_url
    Whodunit::Chronicles.config.database_url = 'postgres://config:pass@localhost/db'

    mock_connection = mock('pg_connection')

    Object.stubs(:require).with('pg')
    PG.expects(:connect).with('postgres://config:pass@localhost/db').returns(mock_connection)

    result = @instance.create_connection

    assert_equal mock_connection, result
  end

  def test_create_connection_unsupported_database_type
    Whodunit::Chronicles.config.adapter = :sqlite

    error = assert_raises(Whodunit::Chronicles::ConfigurationError) do
      @instance.create_connection
    end

    assert_equal 'Unsupported database type for connection', error.message
  end

  def test_connection_active_postgresql_active
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    mock_connection = mock('pg_connection')
    mock_connection.expects(:finished?).returns(false)
    @instance.connection = mock_connection

    assert_predicate @instance, :connection_active?
  end

  def test_connection_active_postgresql_finished
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    mock_connection = mock('pg_connection')
    mock_connection.expects(:finished?).returns(true)
    @instance.connection = mock_connection

    refute_predicate @instance, :connection_active?
  end

  def test_connection_active_postgresql_nil_connection
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    @instance.connection = nil

    refute_predicate @instance, :connection_active?
  end

  def test_connection_active_mysql_active
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    mock_connection = mock('trilogy_connection')
    mock_connection.expects(:ping).returns(true)
    @instance.connection = mock_connection

    assert_predicate @instance, :connection_active?
  end

  def test_connection_active_mysql_inactive
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    mock_connection = mock('trilogy_connection')
    mock_connection.expects(:ping).returns(false)
    @instance.connection = mock_connection

    refute_predicate @instance, :connection_active?
  end

  def test_connection_active_mysql_nil_connection
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    @instance.connection = nil

    refute_predicate @instance, :connection_active?
  end

  def test_connection_active_unsupported_database_type
    Whodunit::Chronicles.config.adapter = :sqlite

    refute_predicate @instance, :connection_active?
  end

  def test_setup_connection_specifics_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    mock_connection = mock('pg_connection')
    mock_type_map = mock('type_map')

    # Stub any potential exec calls that might be made by PG::BasicTypeMapForResults
    mock_connection.stubs(:exec).returns(mock('result'))

    # Mock PG::BasicTypeMapForResults directly
    PG::BasicTypeMapForResults.expects(:new).with(mock_connection).returns(mock_type_map)
    mock_connection.expects(:type_map_for_results=).with(mock_type_map)

    @instance.connection = mock_connection

    @instance.setup_connection_specifics
  end

  def test_setup_connection_specifics_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    mock_connection = mock('trilogy_connection')
    @instance.connection = mock_connection

    # Should not raise any errors and not call any methods on connection
    begin
      @instance.setup_connection_specifics
    rescue StandardError => e
      flunk "Expected no exception, but got: #{e.message}"
    end
  end

  def test_ensure_connection_creates_new_connection_when_nil
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'

    # Mock the connection creation process
    @instance.expects(:create_connection).returns(mock('connection'))
    @instance.expects(:setup_connection_specifics).once
    @instance.expects(:ensure_table_exists).once

    @instance.ensure_connection
  end

  def test_ensure_connection_creates_new_connection_when_inactive
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    old_connection = mock('old_connection')
    @instance.connection = old_connection

    # Mock connection being inactive
    @instance.expects(:connection_active?).returns(false)
    @instance.expects(:create_connection).returns(mock('new_connection'))
    @instance.expects(:setup_connection_specifics).once
    @instance.expects(:ensure_table_exists).once

    @instance.ensure_connection
  end

  def test_ensure_connection_skips_when_connection_active
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    active_connection = mock('active_connection')
    @instance.connection = active_connection

    # Mock connection being active
    @instance.expects(:connection_active?).returns(true)
    @instance.expects(:create_connection).never
    @instance.expects(:setup_connection_specifics).never
    @instance.expects(:ensure_table_exists).never

    @instance.ensure_connection
  end
end
