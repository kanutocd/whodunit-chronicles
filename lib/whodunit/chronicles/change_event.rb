# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Represents a database change event in a common format
    #
    # This class normalizes database changes from different sources
    # (PostgreSQL WAL, MariaDB binlog, etc.) into a consistent format
    # for processing by audit systems.
    class ChangeEvent
      # Supported database actions
      ACTIONS = %w[INSERT UPDATE DELETE].freeze

      attr_reader :table_name, :schema_name, :action, :primary_key, :old_data, :new_data,
        :timestamp, :transaction_id, :sequence_number, :metadata

      # Initialize a new change event
      #
      # @param table_name [String] The name of the table that changed
      # @param action [String] The type of change (INSERT, UPDATE, DELETE)
      # @param primary_key [Hash] The primary key values for the changed row
      # @param old_data [Hash, nil] The row data before the change (nil for INSERT)
      # @param new_data [Hash, nil] The row data after the change (nil for DELETE)
      # @param timestamp [Time] When the change occurred
      # @param schema_name [String] The schema name (optional, defaults to 'public')
      # @param transaction_id [String, Integer] Database transaction identifier
      # @param sequence_number [Integer] Sequence number within the transaction
      # @param metadata [Hash] Additional adapter-specific metadata
      def initialize(
        table_name:,
        action:,
        primary_key:,
        old_data: nil,
        new_data: nil,
        timestamp: Time.now,
        schema_name: 'public',
        transaction_id: nil,
        sequence_number: nil,
        metadata: {}
      )
        @table_name = table_name.to_s
        @schema_name = schema_name.to_s
        @action = validate_action(action.to_s.upcase)
        @primary_key = primary_key || {}
        @old_data = old_data
        @new_data = new_data
        @timestamp = timestamp
        @transaction_id = transaction_id
        @sequence_number = sequence_number
        @metadata = metadata || {}

        validate_data_consistency
      end

      # Get the qualified table name (schema.table)
      #
      # @return [String]
      def qualified_table_name
        "#{schema_name}.#{table_name}"
      end

      # Check if this is a create event
      #
      # @return [Boolean]
      def create?
        action == 'INSERT'
      end

      # Check if this is an update event
      #
      # @return [Boolean]
      def update?
        action == 'UPDATE'
      end

      # Check if this is a delete event
      #
      # @return [Boolean]
      def delete?
        action == 'DELETE'
      end

      # Get the changed columns for UPDATE events
      #
      # @return [Array<String>] Array of column names that changed
      def changed_columns
        return [] unless update? && old_data && new_data

        old_data.keys.reject { |key| old_data[key] == new_data[key] }
      end

      # Get a hash of changes in [old_value, new_value] format
      #
      # @return [Hash] Hash of column_name => [old_value, new_value]
      def changes
        return {} unless update? && old_data && new_data

        changed_columns.each_with_object({}) do |column, changes_hash|
          changes_hash[column] = [old_data[column], new_data[column]]
        end
      end

      # Get the current data for this event
      #
      # @return [Hash] The new_data for INSERT/UPDATE, old_data for DELETE
      def current_data
        case action
        when 'INSERT', 'UPDATE'
          new_data
        when 'DELETE'
          old_data
        end
      end

      # Get all available data for this event
      #
      # @return [Hash] Combined old and new data
      def all_data
        (old_data || {}).merge(new_data || {})
      end

      # Convert to hash representation
      #
      # @return [Hash]
      def to_h
        {
          table_name: table_name,
          schema_name: schema_name,
          qualified_table_name: qualified_table_name,
          action: action,
          primary_key: primary_key,
          old_data: old_data,
          new_data: new_data,
          current_data: current_data,
          changes: changes,
          changed_columns: changed_columns,
          timestamp: timestamp,
          transaction_id: transaction_id,
          sequence_number: sequence_number,
          metadata: metadata,
        }
      end

      # String representation
      #
      # @return [String]
      def to_s
        pk_str = primary_key.map { |k, v| "#{k}=#{v}" }.join(', ')
        "#{action} #{qualified_table_name}(#{pk_str}) at #{timestamp}"
      end

      # Detailed string representation
      #
      # @return [String]
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      # Compare events for equality
      #
      # @param other [ChangeEvent]
      # @return [Boolean]
      def ==(other)
        return false unless other.is_a?(ChangeEvent)

        table_name == other.table_name &&
          schema_name == other.schema_name &&
          action == other.action &&
          primary_key == other.primary_key &&
          old_data == other.old_data &&
          new_data == other.new_data &&
          timestamp == other.timestamp &&
          transaction_id == other.transaction_id &&
          sequence_number == other.sequence_number
      end

      private

      def validate_action(action)
        unless ACTIONS.include?(action)
          raise ArgumentError, "Invalid action: #{action}. Must be one of: #{ACTIONS.join(', ')}"
        end

        action
      end

      def validate_data_consistency
        case action
        when 'INSERT'
          raise ArgumentError, 'INSERT events must have new_data' if new_data.nil? || new_data.empty?
          raise ArgumentError, 'INSERT events should not have old_data' unless old_data.nil?
        when 'UPDATE'
          raise ArgumentError, 'UPDATE events must have both old_data and new_data' if old_data.nil? || new_data.nil?
        when 'DELETE'
          raise ArgumentError, 'DELETE events must have old_data' if old_data.nil? || old_data.empty?
          raise ArgumentError, 'DELETE events should not have new_data' unless new_data.nil?
        end
      end
    end
  end
end
