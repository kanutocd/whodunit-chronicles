# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Handles record persistence for different database adapters
    #
    # Provides adapter-specific SQL for inserting chronicle records
    module Persistence
      private

      def persist_record(record)
        db_type = detect_database_type(@audit_database_url || Chronicles.config.database_url)

        case db_type
        when :postgresql
          persist_record_postgresql(record)
        when :mysql
          persist_record_mysql(record)
        end
      end

      def persist_record_postgresql(record)
        sql = <<~SQL
          INSERT INTO whodunit_chronicles_audits (
            table_name, schema_name, record_id, action, old_data, new_data, changes,
            user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
          RETURNING id
        SQL

        params = build_record_params(record)
        result = @connection.exec_params(sql, params)
        record[:id] = result.first['id'].to_i
        result.clear

        record
      end

      def persist_record_mysql(record)
        sql = <<~SQL
          INSERT INTO whodunit_chronicles_audits (
            table_name, schema_name, record_id, action, old_data, new_data, changes,
            user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL

        params = build_record_params(record)
        @connection.execute(sql, *params)
        record[:id] = @connection.last_insert_id

        record
      end

      def persist_records_batch(records)
        return records if records.empty?

        db_type = detect_database_type(@audit_database_url || Chronicles.config.database_url)

        case db_type
        when :postgresql
          persist_records_batch_postgresql(records)
        when :mysql
          persist_records_batch_mysql(records)
        end
      end

      def persist_records_batch_postgresql(records)
        # Use multi-row INSERT for better performance
        values_clauses = []
        all_params = []
        param_index = 1

        records.each do |record|
          param_positions = (param_index..(param_index + 13)).map { |i| "$#{i}" }.join(', ')
          values_clauses << "(#{param_positions})"
          all_params.concat(build_record_params(record))
          param_index += 14
        end

        sql = <<~SQL
          INSERT INTO whodunit_chronicles_audits (
            table_name, schema_name, record_id, action, old_data, new_data, changes,
            user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
          ) VALUES #{values_clauses.join(', ')}
          RETURNING id
        SQL

        result = @connection.exec_params(sql, all_params)

        # Set IDs on the records
        result.each_with_index do |row, index|
          records[index][:id] = row['id'].to_i
        end

        result.clear
        records
      end

      def persist_records_batch_mysql(records)
        # For MySQL, we'll use individual inserts in a transaction for simplicity
        # A more optimized version could use VALUES() with multiple rows
        records.each do |record|
          persist_record_mysql(record)
        end

        records
      end

      def build_record_params(record)
        [
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
        ]
      end
    end
  end
end
