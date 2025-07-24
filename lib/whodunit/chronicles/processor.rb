# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Processes database change events and creates chronicle records
    #
    # Transforms ChangeEvent objects into structured chronicle records
    # with complete object serialization and metadata.
    class Processor
      include Connection
      include Table
      include Persistence

      attr_reader :logger, :connection

      def initialize(
        audit_database_url: Chronicles.config.audit_database_url,
        logger: Chronicles.logger
      )
        @audit_database_url = audit_database_url
        @logger = logger
        @connection = nil
      end

      # Process a change event and create chronicle record
      #
      # @param change_event [ChangeEvent] The database change to chronicle
      # @return [Hash] The created chronicle record
      def process(change_event)
        ensure_connection

        record = build_record(change_event)
        persist_record(record)

        log(:debug, 'Processed change event',
          table: change_event.qualified_table_name,
          action: change_event.action,
          id: record[:id])

        record
      rescue StandardError => e
        log(:error, 'Failed to process change event',
          error: e.message,
          event: change_event.to_s)
        raise
      end

      # Process multiple change events in a batch
      #
      # @param change_events [Array<ChangeEvent>] Array of change events
      # @return [Array<Hash>] Array of created chronicle records
      def process_batch(change_events)
        return [] if change_events.empty?

        ensure_connection

        records = change_events.map { |event| build_record(event) }
        persist_records_batch(records)

        log(:info, 'Processed batch of change events', count: change_events.size)

        records
      rescue StandardError => e
        log(:error, 'Failed to process batch',
          error: e.message,
          count: change_events.size)
        raise
      end

      # Close database connection
      def close
        @connection&.close
        @connection = nil
      end

      private

      def build_record(change_event)
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

      def log(level, message, context = {})
        logger.public_send(level, message, processor: 'Processor', **context)
      end
    end
  end
end
