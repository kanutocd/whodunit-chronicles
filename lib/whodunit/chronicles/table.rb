# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Handles table creation for different database adapters
    #
    # Provides adapter-specific SQL for creating chronicles tables
    module Table
      private

      def ensure_table_exists
        db_type = detect_database_type(@audit_database_url || Chronicles.config.database_url)

        case db_type
        when :postgresql
          create_postgresql_table
        when :mysql
          create_mysql_table
        end
      end

      def create_postgresql_table
        create_sql = <<~SQL
          CREATE TABLE IF NOT EXISTS whodunit_chronicles_audits (
            id BIGSERIAL PRIMARY KEY,
            table_name TEXT NOT NULL,
            schema_name TEXT NOT NULL DEFAULT 'public',
            record_id JSONB,
            action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
            old_data JSONB,
            new_data JSONB,
            changes JSONB,
            user_id BIGINT,
            user_type TEXT,
            transaction_id TEXT,
            sequence_number INTEGER,
            occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            metadata JSONB DEFAULT '{}'::jsonb,
          #{'  '}
            -- Indexes for performance
            CONSTRAINT valid_data_for_action CHECK (
              (action = 'INSERT' AND old_data IS NULL AND new_data IS NOT NULL) OR
              (action = 'UPDATE' AND old_data IS NOT NULL AND new_data IS NOT NULL) OR#{'  '}
              (action = 'DELETE' AND old_data IS NOT NULL AND new_data IS NULL)
            )
          );

          -- Performance indexes
          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_table_record#{' '}
            ON whodunit_chronicles_audits (table_name, (record_id->>'id'));

          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_occurred_at#{' '}
            ON whodunit_chronicles_audits (occurred_at DESC);

          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_user#{' '}
            ON whodunit_chronicles_audits (user_id, user_type);

          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_action#{' '}
            ON whodunit_chronicles_audits (action);

          -- GIN index for JSONB columns
          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_record_id_gin#{' '}
            ON whodunit_chronicles_audits USING GIN (record_id);

          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chronicles_audits_changes_gin#{' '}
            ON whodunit_chronicles_audits USING GIN (changes);
        SQL

        @connection.exec(create_sql)
      rescue PG::Error => e
        # Ignore "already exists" errors from CONCURRENTLY
        raise unless e.message.include?('already exists')
      end

      def create_mysql_table
        create_sql = <<~SQL
          CREATE TABLE IF NOT EXISTS whodunit_chronicles_audits (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            table_name TEXT NOT NULL,
            schema_name TEXT NOT NULL DEFAULT 'public',
            record_id JSON,
            action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
            old_data JSON,
            new_data JSON,
            changes JSON,
            user_id BIGINT,
            user_type TEXT,
            transaction_id TEXT,
            sequence_number INTEGER,
            occurred_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            metadata JSON DEFAULT (JSON_OBJECT()),
          #{'  '}
            -- Constraint for data integrity
            CONSTRAINT valid_data_for_action CHECK (
              (action = 'INSERT' AND old_data IS NULL AND new_data IS NOT NULL) OR
              (action = 'UPDATE' AND old_data IS NOT NULL AND new_data IS NOT NULL) OR
              (action = 'DELETE' AND old_data IS NOT NULL AND new_data IS NULL)
            ),
          #{'  '}
            -- Performance indexes
            INDEX idx_chronicles_audits_table_record (table_name(255), (JSON_UNQUOTE(JSON_EXTRACT(record_id, '$.id')))),
            INDEX idx_chronicles_audits_occurred_at (occurred_at DESC),
            INDEX idx_chronicles_audits_user (user_id, user_type(255)),
            INDEX idx_chronicles_audits_action (action(50))
          );
        SQL

        @connection.query(create_sql)
      rescue StandardError => e
        # Ignore "already exists" errors
        unless e.message.include?('already exists') ||
               (e.message.include?('Table') && e.message.include?('already exists'))
          raise
        end
      end
    end
  end
end
