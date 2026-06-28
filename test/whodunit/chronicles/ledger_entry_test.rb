# frozen_string_literal: true

require 'test_helper'

class LedgerEntryTest < Minitest::Test
  Clock = Data.define(:now)

  def test_builds_immutable_entry_from_cdc_change_event
    now = Time.utc(2026, 1, 1, 0, 0, 1)
    event = sample_change_event(
      operation: :update,
      old_values: { id: 1, name: 'Alice' },
      new_values: { id: 1, name: 'Bob' }
    )

    entry = Whodunit::Chronicles::LedgerEntry.from_change_event(event, clock: Clock.new(now))

    assert_match(/\A[0-9a-f]{64}\z/, entry.event_id)
    assert_equal Time.utc(2026, 1, 1, 0, 0, 0), entry.occurred_at
    assert_equal now, entry.recorded_at
    assert_equal 'public', entry.namespace
    assert_equal 'users', entry.entity
    assert_equal({ 'id' => 1 }, entry.identity)
    assert_equal :update, entry.operation
    assert_equal({ 'id' => 42 }, entry.actor)
    assert_equal [{ 'name' => 'name', 'old_value' => 'Alice', 'new_value' => 'Bob' }], entry.changes
    assert_equal 'tx-1', entry.metadata.fetch('transaction_id')
    assert_equal '0/1', entry.metadata.fetch('source_position')
    assert_equal 1, entry.metadata.fetch('sequence_number')
    assert_equal event.to_h, entry.payload
    assert_predicate entry, :frozen?
  end

  def test_from_event_aliases_from_change_event
    entry = Whodunit::Chronicles::LedgerEntry.from_event(sample_change_event)

    assert_instance_of Whodunit::Chronicles::LedgerEntry, entry
  end

  def test_to_h_and_ordering_identity
    entry = Whodunit::Chronicles::LedgerEntry.from_change_event(sample_change_event)

    assert_equal 'public:users:{"id" => 1}', entry.ordering_identity
    assert_equal 'users', entry.to_h.fetch(:entity)
  end

  def test_uses_clock_when_occurred_at_is_absent
    now = Time.utc(2026, 2, 2)
    event = CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'logs')

    entry = Whodunit::Chronicles::LedgerEntry.from_change_event(event, clock: Clock.new(now))

    assert_equal now, entry.occurred_at
    assert_equal now, entry.recorded_at
  end

  def test_extracts_whodunit_when_actor_is_absent
    event = CDC::Core::ChangeEvent.new(
      operation: :insert,
      schema: 'public',
      table: 'logs',
      metadata: { whodunit: 'alice' }
    )

    entry = Whodunit::Chronicles::LedgerEntry.from_change_event(event)

    assert_equal 'alice', entry.actor
  end

  def test_generates_deterministic_event_id_from_cdc_payload
    event = sample_change_event

    first = Whodunit::Chronicles::LedgerEntry.from_change_event(event)
    second = Whodunit::Chronicles::LedgerEntry.from_change_event(event)

    assert_equal first.event_id, second.event_id
  end

  def test_rejects_non_cdc_core_change_event
    error = assert_raises(TypeError) do
      Whodunit::Chronicles::LedgerEntry.from_change_event({ operation: 'insert' })
    end

    assert_match(/expected CDC::Core::ChangeEvent/, error.message)
  end
end
