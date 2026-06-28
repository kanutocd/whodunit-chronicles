# frozen_string_literal: true

require 'test_helper'

class ChroniclerTest < Minitest::Test
  class CapableLedger < Whodunit::Chronicles::Ledger
    attr_reader :prepared, :indexed, :entries

    def initialize
      @entries = []
    end

    def prepare!
      @prepared = true
      self
    end

    def ensure_indexes!
      @indexed = true
      self
    end

    def append(entry)
      @entries << entry
      entry
    end
  end

  class AppendOnlyLedger
    attr_reader :entries

    def initialize
      @entries = []
    end

    def append(entry)
      @entries << entry
      entry
    end
  end

  class PartitioningLedger < Whodunit::Chronicles::Ledger
    attr_reader :partitions

    def initialize
      @partitions = Hash.new { |hash, key| hash[key] = Whodunit::Chronicles::Ledgers::MemoryLedger.new }
    end

    def partition_for(entry)
      @partitions[entry.entity]
    end
  end

  def test_is_a_cdc_core_processor
    chronicler = Whodunit::Chronicles::Chronicler.new(ledger: Whodunit::Chronicles::Ledgers::MemoryLedger.new)

    assert_kind_of CDC::Core::Processor, chronicler
    assert_predicate chronicler, :healthy?
    assert_same chronicler, chronicler.start
    assert_same chronicler, chronicler.flush
    assert_same chronicler, chronicler.stop
  end

  def test_prepares_and_indexes_capable_ledger
    ledger = CapableLedger.new

    Whodunit::Chronicles::Chronicler.new(ledger: ledger)

    assert ledger.prepared
    assert ledger.indexed
  end

  def test_can_skip_prepare_and_index_calls
    ledger = CapableLedger.new

    Whodunit::Chronicles::Chronicler.new(ledger: ledger, prepare: false, ensure_indexes: false)

    assert_nil ledger.prepared
    assert_nil ledger.indexed
  end

  def test_accepts_append_only_duck_typed_ledger
    ledger = AppendOnlyLedger.new
    chronicler = Whodunit::Chronicles::Chronicler.new(ledger: ledger)

    event = sample_change_event
    result = chronicler.process(event)

    assert_predicate result, :success?
    assert_equal 1, ledger.entries.length
  end

  def test_process_appends_entry_and_returns_cdc_success
    ledger = Whodunit::Chronicles::Ledgers::MemoryLedger.new
    chronicler = Whodunit::Chronicles::Chronicler.new(ledger: ledger)

    event = sample_change_event
    result = chronicler.process(event)

    assert_instance_of CDC::Core::ProcessorResult, result
    assert_predicate result, :success?
    refute_predicate result, :failure?
    assert_equal 1, ledger.entries.length
    assert_instance_of Whodunit::Chronicles::LedgerEntry, ledger.entries.first
    assert_same event, result.event
  end

  def test_process_uses_partition_when_available
    ledger = PartitioningLedger.new
    chronicler = Whodunit::Chronicles::Chronicler.new(ledger: ledger)

    chronicler.process(sample_change_event(table: 'users'))
    chronicler.process(sample_change_event(table: 'orders'))

    assert_equal 1, ledger.partitions['users'].entries.length
    assert_equal 1, ledger.partitions['orders'].entries.length
  end

  def test_process_returns_cdc_failure_result_when_append_fails
    ledger = Class.new(Whodunit::Chronicles::Ledger) do
      def append(_entry)
        raise 'boom'
      end
    end.new
    chronicler = Whodunit::Chronicles::Chronicler.new(ledger: ledger)

    result = chronicler.process(sample_change_event)

    assert_instance_of CDC::Core::ProcessorResult, result
    assert_predicate result, :failure?
    refute_predicate result, :success?
    assert_predicate result, :retryable?
    assert_instance_of RuntimeError, result.error
    assert_equal Whodunit::Chronicles::Chronicler.name, result.processor_name
  end
end
