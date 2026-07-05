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
        adapter = required_value(ledger, 'adapter')

        case adapter
        when 'memory'
          Ledgers::MemoryLedger.new
        when 'file'
          Ledgers::FileLedger.new(path: required_value(ledger, 'path'))
        when 'sqlite'
          Ledgers::SQLiteLedger.new(path: required_value(ledger, 'path'), table_name: ledger.fetch('table_name', Ledgers::SQLiteLedger::DEFAULT_TABLE))
        else
          raise ConfigurationError, "unsupported ledger adapter: #{adapter.inspect}"
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

      # Fetch a required config value with a user-facing error.
      def required_value(config, key)
        config.fetch(key)
      rescue KeyError
        raise ConfigurationError, "missing ledger #{key}"
      end
    end
  end
end
