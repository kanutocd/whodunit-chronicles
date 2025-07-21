# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Processes database change events and creates audit records
    #
    # Transforms ChangeEvent objects into structured audit records
    # with complete object serialization and metadata.
    class AuditProcessor
      attr_reader :logger, :audit_connection

      def initialize(
        audit_database_url: Chronicles.config.audit_database_url,
        logger: Chronicles.logger
      )
        @audit_database_url = audit_database_url
        @logger = logger
        @audit_connection = nil
      end

      # Process a change event and create audit record
      #
      # @param change_event [ChangeEvent] The database change to audit
      # @return [Hash] The created audit record
      def process(change_event)
        ensure_audit_connection

        audit_record = build_audit_record(change_event)
        persist_audit_record(audit_record)

        log(:debug, 'Processed change event',
          table: change_event.qualified_table_name,
          action: change_event.action,
          audit_id: audit_record[:id])

        audit_record
      rescue StandardError => e
        log(:error, 'Failed to process change event',
          error: e.message,
          event: change_event.to_s)
        raise
      end

      # Process multiple change events in a batch
      #
      # @param change_events [Array<ChangeEvent>] Array of change events
      # @return [Array<Hash>] Array of created audit records
      def process_batch(change_events)
        return [] if change_events.empty?

        ensure_audit_connection

        audit_records = change_events.map { |event| build_audit_record(event) }
        persist_audit_records_batch(audit_records)

        log(:info, 'Processed batch of change events', count: change_events.size)

        audit_records
      rescue StandardError => e
        log(:error, 'Failed to process batch',
          error: e.message,
          count: change_events.size)
        raise
      end

      # Close audit database connection
      def close
        @audit_connection&.close
        @audit_connection = nil
      end

      private

      def ensure_audit_connection
        return if @audit_connection && !@audit_connection.finished?

        @audit_connection = PG.connect(@audit_database_url || Chronicles.config.database_url)
        @audit_connection.type_map_for_results = PG::BasicTypeMapForResults.new(@audit_connection)

        ensure_audit_table_exists
      end

      def ensure_audit_table_exists
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

        @audit_connection.exec(create_sql)
      rescue PG::Error => e
        # Ignore "already exists" errors from CONCURRENTLY
        raise unless e.message.include?('already exists')
      end

      def build_audit_record(change_event)
        user_info = extract_user_info(change_event)

        {
          id: nil, # Will be set by database
          table_name: change_event.table_name,
          schema_name: change_event.schema_name,
          record_id: change_event.primary_key,
          action: change_event.action,
          old_data: change_event.old_data,
          new_data: change_event.new_data,
          changes: change_event.changes,
          user_id: user_info[:user_id],
          user_type: user_info[:user_type],
          transaction_id: change_event.transaction_id,
          sequence_number: change_event.sequence_number,
          occurred_at: change_event.timestamp,
          created_at: Time.now,
          metadata: build_metadata(change_event),
        }
      end

      def extract_user_info(change_event)
        data = change_event.current_data || {}

        # Look for Whodunit user attribution fields
        user_id = data['creator_id'] || data['updater_id'] || data['deleter_id']

        {
          user_id: user_id,
          user_type: user_id ? 'User' : nil,
        }
      end

      def build_metadata(change_event)
        {
          table_schema: change_event.schema_name,
          qualified_table_name: change_event.qualified_table_name,
          changed_columns: change_event.changed_columns,
          adapter_metadata: change_event.metadata,
          chronicles_version: Chronicles::VERSION,
        }
      end

      def persist_audit_record(audit_record)
        sql = <<~SQL
          INSERT INTO whodunit_chronicles_audits (
            table_name, schema_name, record_id, action, old_data, new_data, changes,
            user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
          RETURNING id
        SQL

        params = [
          audit_record[:table_name],
          audit_record[:schema_name],
          audit_record[:record_id].to_json,
          audit_record[:action],
          audit_record[:old_data]&.to_json,
          audit_record[:new_data]&.to_json,
          audit_record[:changes].to_json,
          audit_record[:user_id],
          audit_record[:user_type],
          audit_record[:transaction_id],
          audit_record[:sequence_number],
          audit_record[:occurred_at],
          audit_record[:created_at],
          audit_record[:metadata].to_json,
        ]

        result = @audit_connection.exec_params(sql, params)
        audit_record[:id] = result.first['id'].to_i
        result.clear

        audit_record
      end

      def persist_audit_records_batch(audit_records)
        return audit_records if audit_records.empty?

        # Use multi-row INSERT for better performance
        values_clauses = []
        all_params = []
        param_index = 1

        audit_records.each do |record|
          param_positions = (param_index..(param_index + 13)).map { |i| "$#{i}" }.join(', ')
          values_clauses << "(#{param_positions})"

          all_params.push(
            record[:table_name],
            record[:schema_name],
            record[:record_id].to_json,
            record[:action],
            record[:old_data]&.to_json,
            record[:new_data]&.to_json,
            record[:changes].to_json,
            record[:user_id],
            record[:user_type],
            record[:transaction_id],
            record[:sequence_number],
            record[:occurred_at],
            record[:created_at],
            record[:metadata].to_json,
          )

          param_index += 14
        end

        sql = <<~SQL
          INSERT INTO whodunit_chronicles_audits (
            table_name, schema_name, record_id, action, old_data, new_data, changes,
            user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
          ) VALUES #{values_clauses.join(', ')}
          RETURNING id
        SQL

        result = @audit_connection.exec_params(sql, all_params)

        # Set IDs on the audit records
        result.each_with_index do |row, index|
          audit_records[index][:id] = row['id'].to_i
        end

        result.clear
        audit_records
      end

      def log(level, message, context = {})
        logger.public_send(level, message, processor: 'AuditProcessor', **context)
      end
    end
  end
end
