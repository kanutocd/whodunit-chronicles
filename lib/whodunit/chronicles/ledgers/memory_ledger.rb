# frozen_string_literal: true

require_relative '../ledger'

module Whodunit
  module Chronicles
    module Ledgers
      # In-memory append-only ledger for tests, examples, and small scripts.
      class MemoryLedger < Ledger
        # @return [Array<LedgerEntry>] appended entries in insertion order
        attr_reader :entries

        # Create an empty in-memory ledger.
        def initialize
          @entries = []
        end

        # Append an entry to memory.
        #
        # @param entry [LedgerEntry] entry to append
        # @return [LedgerEntry] appended entry
        def append(entry)
          @entries << entry
          entry
        end
      end
    end
  end
end
