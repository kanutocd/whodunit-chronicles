# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    class ConfigurationTest < Minitest::Test
      def setup
        super
        @config = Whodunit::Chronicles::Configuration.new
      end

      def test_default_configuration
        assert_nil @config.audit_database_url
        assert_equal :postgresql, @config.adapter
        assert_equal 'whodunit_audit', @config.publication_name
        assert_equal 'whodunit_audit_slot', @config.replication_slot_name
        assert_equal 100, @config.batch_size
        assert_equal 3, @config.max_retry_attempts
        assert_equal 5, @config.retry_delay
      end

      def test_configuration_with_environment_variables
        ENV['DATABASE_URL'] = 'postgresql://localhost/test'
        ENV['AUDIT_DATABASE_URL'] = 'postgresql://localhost/audit'

        config = Whodunit::Chronicles::Configuration.new

        assert_equal 'postgresql://localhost/test', config.database_url
        assert_equal 'postgresql://localhost/audit', config.audit_database_url
      ensure
        ENV.delete('DATABASE_URL')
        ENV.delete('AUDIT_DATABASE_URL')
      end

      def test_validation_passes_with_valid_config
        @config.database_url = 'postgresql://localhost/test'

        assert_nil @config.validate!
      end

      def test_validation_fails_without_database_url
        @config.database_url = nil

        error = assert_raises Whodunit::Chronicles::ConfigurationError do
          @config.validate!
        end
        assert_includes error.message, 'database_url is required'
      end

      def test_validation_fails_with_invalid_adapter
        @config.database_url = 'postgresql://localhost/test'
        @config.adapter = :invalid

        error = assert_raises Whodunit::Chronicles::ConfigurationError do
          @config.validate!
        end
        assert_includes error.message, 'adapter must be :postgresql or :mysql'
      end

      def test_validation_passes_with_mysql_adapter
        @config.database_url = 'mysql://localhost/test'
        @config.adapter = :mysql

        # Should not raise
        @config.validate!
      end

      def test_validation_passes_with_postgresql_adapter
        @config.database_url = 'postgresql://localhost/test'
        @config.adapter = :postgresql

        # Should not raise
        @config.validate!
      end

      def test_validation_fails_with_invalid_batch_size
        @config.database_url = 'postgresql://localhost/test'
        @config.batch_size = 0

        error = assert_raises Whodunit::Chronicles::ConfigurationError do
          @config.validate!
        end
        assert_includes error.message, 'batch_size must be positive'
      end

      def test_validation_fails_with_invalid_publication_name
        @config.database_url = 'postgresql://localhost/test'
        @config.publication_name = '123invalid'

        error = assert_raises Whodunit::Chronicles::ConfigurationError do
          @config.validate!
        end
        assert_includes error.message, 'publication_name must be a valid PostgreSQL identifier'
      end

      def test_validation_fails_with_invalid_slot_name
        @config.database_url = 'postgresql://localhost/test'
        @config.replication_slot_name = 'invalid-slot'

        error = assert_raises Whodunit::Chronicles::ConfigurationError do
          @config.validate!
        end
        assert_includes error.message, 'replication_slot_name must be a valid PostgreSQL identifier'
      end

      def test_chronicle_table_with_no_filters
        assert @config.chronicle_table?('users', 'public')
        assert @config.chronicle_table?('orders', 'sales')
      end

      def test_chronicle_table_with_schema_filter_array
        @config.schema_filter = %w[public sales]

        assert @config.chronicle_table?('users', 'public')
        assert @config.chronicle_table?('orders', 'sales')
        refute @config.chronicle_table?('logs', 'audit')
      end

      def test_chronicle_table_with_schema_filter_string
        @config.schema_filter = 'public'

        assert @config.chronicle_table?('users', 'public')
        refute @config.chronicle_table?('orders', 'sales')
      end

      def test_chronicle_table_with_schema_filter_proc
        @config.schema_filter = ->(schema) { schema == 'public' }

        assert @config.chronicle_table?('users', 'public')
        refute @config.chronicle_table?('orders', 'sales')
      end

      def test_chronicle_table_with_table_filter_array
        @config.table_filter = %w[users orders]

        assert @config.chronicle_table?('users', 'public')
        assert @config.chronicle_table?('orders', 'public')
        refute @config.chronicle_table?('logs', 'public')
      end

      def test_chronicle_table_with_table_filter_regexp
        @config.table_filter = /^user/

        assert @config.chronicle_table?('users', 'public')
        assert @config.chronicle_table?('user_profiles', 'public')
        refute @config.chronicle_table?('orders', 'public')
      end

      def test_chronicle_table_with_table_filter_proc
        @config.table_filter = ->(table) { table.start_with?('user') }

        assert @config.chronicle_table?('users', 'public')
        assert @config.chronicle_table?('user_profiles', 'public')
        refute @config.chronicle_table?('orders', 'public')
      end

      def test_chronicle_table_with_combined_filters
        @config.schema_filter = %w[public]
        @config.table_filter = %w[users orders]

        assert @config.chronicle_table?('users', 'public')
        refute @config.chronicle_table?('users', 'audit')
        refute @config.chronicle_table?('logs', 'public')
      end
    end
  end
end
