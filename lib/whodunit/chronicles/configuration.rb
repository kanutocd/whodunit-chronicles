# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Configuration management for Chronicles
    #
    # Provides a centralized configuration system with sensible defaults
    # and validation for all Chronicles settings.
    class Configuration
      attr_accessor :database_url, :audit_database_url, :adapter, :publication_name,
        :replication_slot_name, :batch_size, :max_retry_attempts, :retry_delay,
        :logger, :table_filter, :schema_filter

      def initialize
        @database_url = ENV.fetch('DATABASE_URL', nil)
        @audit_database_url = ENV.fetch('AUDIT_DATABASE_URL', nil)
        @adapter = :postgresql
        @publication_name = 'whodunit_audit'
        @replication_slot_name = 'whodunit_audit_slot'
        @batch_size = 100
        @max_retry_attempts = 3
        @retry_delay = 5
        @logger = Dry::Logger.new
        @table_filter = nil
        @schema_filter = nil
      end

      # Validate configuration settings
      #
      # @raise [ConfigurationError] if configuration is invalid
      def validate!
        raise ConfigurationError, 'database_url is required' if database_url.nil?
        raise ConfigurationError, 'adapter must be :postgresql or :mysql' unless %i[postgresql mysql].include?(adapter)
        raise ConfigurationError, 'batch_size must be positive' unless batch_size.positive?
        raise ConfigurationError, 'max_retry_attempts must be positive' unless max_retry_attempts.positive?
        raise ConfigurationError, 'retry_delay must be positive' unless retry_delay.positive?

        validate_adapter_specific_settings!
      end

      # Check if a table should be chronicled based on filters
      #
      # @param table_name [String] The table name to check
      # @param schema_name [String] The schema name to check
      # @return [Boolean] true if the table should be chronicled
      def chronicle_table?(table_name, schema_name = 'public')
        return false if filtered_by_schema?(schema_name)
        return false if filtered_by_table?(table_name)

        true
      end

      private

      def validate_adapter_specific_settings!
        case adapter
        when :postgresql
          validate_postgresql_settings!
        when :mysql
          validate_mysql_settings!
        end
      end

      def validate_postgresql_settings!
        if publication_name && !/\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(publication_name)
          raise ConfigurationError, 'publication_name must be a valid PostgreSQL identifier'
        end

        return unless replication_slot_name && !/\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(replication_slot_name)

        raise ConfigurationError, 'replication_slot_name must be a valid PostgreSQL identifier'
      end

      def validate_mysql_settings!
        # MySQL-specific validations can be added here in the future
        # For now, MySQL settings are less restrictive
      end

      def filtered_by_schema?(schema_name)
        return false unless schema_filter

        case schema_filter
        when Array
          !schema_filter.include?(schema_name)
        when String, Symbol
          schema_name != schema_filter.to_s
        when Proc
          !schema_filter.call(schema_name)
        else
          false
        end
      end

      def filtered_by_table?(table_name)
        return false unless table_filter

        case table_filter
        when Array
          !table_filter.include?(table_name)
        when String, Symbol
          table_name != table_filter.to_s
        when Regexp
          !table_filter.match?(table_name)
        when Proc
          !table_filter.call(table_name)
        else
          false
        end
      end
    end
  end
end
