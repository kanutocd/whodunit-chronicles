# frozen_string_literal: true

require 'uri'

module Whodunit
  module Chronicles
    # Handles database connections for chronicles processing
    #
    # Provides adapter-agnostic connection management for both PostgreSQL and MySQL
    module Connection
      private

      def create_connection
        audit_url = @audit_database_url || Chronicles.config.database_url

        case detect_database_type(audit_url)
        when :postgresql
          require 'pg'
          PG.connect(audit_url)
        when :mysql
          require 'trilogy'
          parsed = parse_mysql_url(audit_url)
          Trilogy.new(
            host: parsed[:host],
            port: parsed[:port] || 3306,
            username: parsed[:username],
            password: parsed[:password],
            database: parsed[:database],
            ssl: parsed[:ssl],
          )
        else
          raise ConfigurationError, 'Unsupported database type for connection'
        end
      end

      def detect_database_type(url)
        return Chronicles.config.adapter unless url
        return :postgresql if url.start_with?('postgres://', 'postgresql://')
        return :mysql if url.start_with?('mysql://', 'mysql2://')

        # Fallback to configured adapter
        Chronicles.config.adapter
      end

      def parse_mysql_url(url)
        return {} if url.nil? || url.empty?

        uri = URI.parse(url)
        {
          host: uri.host,
          port: uri.port,
          username: uri.user,
          password: uri.password,
          database: uri.path&.sub('/', ''),
          ssl: uri.query&.include?('ssl=true'),
        }
      end

      def connection_active?
        case detect_database_type(@audit_database_url || Chronicles.config.database_url)
        when :postgresql
          @connection && !@connection.finished?
        when :mysql
          @connection&.ping
        else
          false
        end
      end

      def setup_connection_specifics
        case detect_database_type(@audit_database_url || Chronicles.config.database_url)
        when :postgresql
          @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
        when :mysql
          # MySQL/Trilogy doesn't need special setup
        end
      end

      def ensure_connection
        return if @connection && connection_active?

        @connection = create_connection
        setup_connection_specifics
        ensure_table_exists
      end
    end
  end
end
