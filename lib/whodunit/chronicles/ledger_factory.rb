# frozen_string_literal: true

require_relative 'errors'
require_relative 'ledgers/memory_ledger'
require_relative 'ledgers/file_ledger'
require_relative 'ledgers/sqlite_ledger'

module Whodunit
  module Chronicles
    # Builds ledger instances from simple configuration hashes.
    class LedgerFactory
      # Build a ledger from configuration.
      #
      # @param config [Hash] configuration hash
      # @return [Ledger] configured ledger
      def self.build(config)
        new(config).build
      end

      # Create a factory.
      #
      # @param config [Hash] configuration hash
      def initialize(config)
        @config = stringify_keys(config)
      end

      # Build the configured ledger.
      #
      # @return [Ledger] configured ledger
      def build
        ledger = stringify_keys(@config.fetch('ledger', @config))
        case ledger.fetch('adapter')
        when 'memory'
          Ledgers::MemoryLedger.new
        when 'file'
          Ledgers::FileLedger.new(path: ledger.fetch('path'))
        when 'sqlite'
          Ledgers::SQLiteLedger.new(path: ledger.fetch('path'), table_name: ledger.fetch('table_name', Ledgers::SQLiteLedger::DEFAULT_TABLE))
        else
          raise ConfigurationError, "unsupported ledger adapter: #{ledger.fetch('adapter', nil).inspect}"
        end
      end

      private

      # Convert hash keys to strings recursively.
      def stringify_keys(value)
        case value
        when Hash
          value.to_h { |key, nested| [key.to_s, stringify_keys(nested)] }
        else
          value
        end
      end
    end
  end
end
