# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Base class for append-only audit ledgers.
    #
    # Ledger is the minimal storage contract consumed by {Chronicler}. Concrete
    # ledgers only need to implement {#append}; preparation, indexing, and
    # partitioning are optional capabilities with safe defaults.
    class Ledger
      # Prepare backing storage if the ledger supports schema creation.
      #
      # @return [Ledger] this ledger
      def prepare!
        self
      end

      # Ensure useful indexes if the ledger supports index management.
      #
      # @return [Ledger] this ledger
      def ensure_indexes!
        self
      end

      # Apply storage evolution steps if the ledger supports migrations.
      #
      # @return [Ledger] this ledger
      def migrate!
        prepare!
        ensure_indexes!
        self
      end

      # Verify that the ledger is operational.
      #
      # @return [Boolean] true when the ledger appears usable
      def verify
        true
      end

      # Return lightweight operational status for this ledger.
      #
      # @return [Hash<Symbol, Object>] ledger status
      def status
        { adapter: self.class.name, ready: verify }
      end

      # Return the target ledger for an entry.
      #
      # Partition-aware ledgers override this method. Simple ledgers return
      # themselves.
      #
      # @param entry [LedgerEntry] entry being appended
      # @return [Ledger] ledger that should receive the entry
      def partition_for(_entry)
        self
      end

      # Append an immutable entry to the ledger.
      #
      # @param entry [LedgerEntry] entry to persist
      # @raise [NotImplementedError] when not implemented by a concrete ledger
      # @return [Object] implementation-defined result
      def append(_entry)
        raise NotImplementedError, "#{self.class} must implement #append"
      end
    end
  end
end
