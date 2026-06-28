# frozen_string_literal: true

require 'cdc_core'

require_relative 'ledger_entry'

module Whodunit
  module Chronicles
    # Minimal CDC::Core processor that records change events into a ledger.
    #
    # Chronicler is intentionally small. It consumes a {CDC::Core::ChangeEvent},
    # converts it into an immutable {LedgerEntry}, and appends that entry into
    # the provided ledger. Scheduling, retries, backpressure, worker pools, and
    # orchestration belong to CDC runtimes outside this gem.
    class Chronicler < CDC::Core::Processor
      # @return [Object] ledger receiving immutable entries
      attr_reader :ledger

      # Create a chronicler.
      #
      # @param ledger [#append] ledger-like object
      # @param prepare [Boolean] whether to call ledger.prepare! during initialization
      # @param ensure_indexes [Boolean] whether to call ledger.ensure_indexes! during initialization
      # @param clock [#now] clock used when creating ledger entries
      def initialize(ledger:, prepare: true, ensure_indexes: true, clock: Time)
        @ledger = ledger
        @clock = clock
        @ledger.prepare! if prepare && @ledger.respond_to?(:prepare!)
        @ledger.ensure_indexes! if ensure_indexes && @ledger.respond_to?(:ensure_indexes!)
      end

      # Process one CDC change event and append one ledger entry.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [CDC::Core::ProcessorResult] standardized processor result
      def process(event)
        entry = LedgerEntry.from_change_event(event, clock: @clock)
        partition_for(entry).append(entry)
        CDC::Core::ProcessorResult.success(event)
      rescue StandardError => e
        CDC::Core::ProcessorResult.failure(
          e,
          event: event,
          processor: self.class.name,
          retryable: true
        )
      end

      private

      # Resolve the ledger partition for an entry.
      #
      # @param entry [LedgerEntry] entry being appended
      # @return [Object] ledger-like target
      def partition_for(entry)
        return @ledger.partition_for(entry) if @ledger.respond_to?(:partition_for)

        @ledger
      end
    end
  end
end
