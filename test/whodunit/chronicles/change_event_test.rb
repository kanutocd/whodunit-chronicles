# frozen_string_literal: true

require 'test_helper'

module Whodunit
  module Chronicles
    class ChangeEventTest < Minitest::Test
      def test_insert_event_creation
        event = create_change_event(action: 'INSERT')

        assert_equal 'INSERT', event.action
        assert_equal 'users', event.table_name
        assert_equal 'public', event.schema_name
        assert_equal({ 'id' => 1 }, event.primary_key)
        assert_nil event.old_data
        refute_nil event.new_data
        assert_predicate event, :create?
        refute_predicate event, :update?
        refute_predicate event, :delete?
      end

      def test_update_event_creation
        event = create_change_event(action: 'UPDATE')

        assert_equal 'UPDATE', event.action
        refute_nil event.old_data
        refute_nil event.new_data
        refute_predicate event, :create?
        assert_predicate event, :update?
        refute_predicate event, :delete?
      end

      def test_delete_event_creation
        event = create_change_event(action: 'DELETE')

        assert_equal 'DELETE', event.action
        refute_nil event.old_data
        assert_nil event.new_data
        refute_predicate event, :create?
        refute_predicate event, :update?
        assert_predicate event, :delete?
      end

      def test_qualified_table_name
        event = create_change_event(schema_name: 'audit', table_name: 'logs')

        assert_equal 'audit.logs', event.qualified_table_name
      end

      def test_changed_columns_for_update
        event = create_change_event(action: 'UPDATE')
        expected = %w[name email]

        assert_equal expected.sort, event.changed_columns.sort
      end

      def test_changes_hash_for_update
        event = create_change_event(action: 'UPDATE')
        expected_changes = {
          'name' => %w[Ken Sophia],
          'email' => %w[spherical.cow@example.com sophia@example.com],
        }

        assert_equal expected_changes, event.changes
      end

      def test_current_data_for_insert
        event = create_change_event(action: 'INSERT')

        assert_equal event.new_data, event.current_data
      end

      def test_current_data_for_update
        event = create_change_event(action: 'UPDATE')

        assert_equal event.new_data, event.current_data
      end

      def test_current_data_for_delete
        event = create_change_event(action: 'DELETE')

        assert_equal event.old_data, event.current_data
      end

      def test_all_data_combines_old_and_new
        event = create_change_event(action: 'UPDATE')
        expected = event.old_data.merge(event.new_data)

        assert_equal expected, event.all_data
      end

      def test_string_representation
        event = create_change_event(action: 'INSERT')

        assert_includes event.to_s, 'INSERT'
        assert_includes event.to_s, 'public.users'
        assert_includes event.to_s, 'id=1'
      end

      def test_equality
        timestamp = Time.now
        event1 = create_change_event(action: 'INSERT', timestamp: timestamp)
        event2 = create_change_event(action: 'INSERT', timestamp: timestamp)

        # Same data should be equal
        assert_equal event1, event2

        # Different action should not be equal
        event3 = create_change_event(action: 'UPDATE', timestamp: timestamp)

        refute_equal event1, event3
      end

      def test_invalid_action_raises_error
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'INVALID',
            primary_key: { 'id' => 1 },
          )
        end
      end

      def test_insert_validation_requires_new_data
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'INSERT',
            primary_key: { 'id' => 1 },
            new_data: nil,
          )
        end
      end

      def test_insert_validation_rejects_old_data
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'INSERT',
            primary_key: { 'id' => 1 },
            old_data: { 'id' => 1 },
            new_data: { 'id' => 1, 'name' => 'Ken' },
          )
        end
      end

      def test_update_validation_requires_both_data
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'UPDATE',
            primary_key: { 'id' => 1 },
            old_data: nil,
            new_data: { 'id' => 1, 'name' => 'Ken' },
          )
        end
      end

      def test_delete_validation_requires_old_data
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'DELETE',
            primary_key: { 'id' => 1 },
            old_data: nil,
          )
        end
      end

      def test_delete_validation_rejects_new_data
        assert_raises ArgumentError do
          Whodunit::Chronicles::ChangeEvent.new(
            table_name: 'users',
            action: 'DELETE',
            primary_key: { 'id' => 1 },
            old_data: { 'id' => 1, 'name' => 'Ken' },
            new_data: { 'id' => 1, 'name' => 'Sophia' },
          )
        end
      end
    end
  end
end
