# frozen_string_literal: true

require 'yaml'
require_relative 'ledger_factory'

module Whodunit
  module Chronicles
    # Small operational command-line interface for ledger lifecycle tasks.
    #
    # The CLI owns book preparation, migration-like operations, index creation,
    # verification, and status checks. The runtime chronicler only appends
    # entries into a ledger it has been handed.
    class CLI
      # Run a command with argv-style arguments.
      #
      # @param argv [Array<String>] command-line arguments
      # @param out [#puts] output stream
      # @param err [#puts] error stream
      # @return [Integer] process-style exit code
      def self.run(argv, out: $stdout, err: $stderr)
        new(argv: argv, out: out, err: err).run
      end

      # Create a CLI instance.
      #
      # @param argv [Array<String>] command-line arguments
      # @param out [#puts] output stream
      # @param err [#puts] error stream
      def initialize(argv:, out:, err:)
        @argv = argv.dup
        @out = out
        @err = err
      end

      # Execute the requested command.
      #
      # @return [Integer] process-style exit code
      def run
        return usage(0) if @argv.empty? || @argv.first == 'help'

        namespace = @argv.shift
        command = @argv.shift
        config_path = @argv.shift
        return usage(1) unless namespace == 'ledger' && command && config_path

        ledger = LedgerFactory.build(load_config(config_path))
        execute_ledger_command(ledger, command)
      rescue StandardError => e
        @err.puts(e.message)
        1
      end

      private

      # Execute a ledger lifecycle command.
      def execute_ledger_command(ledger, command)
        case command
        when 'prepare'
          ledger.prepare!
          @out.puts('prepared')
        when 'migrate'
          ledger.migrate!
          @out.puts('migrated')
        when 'ensure-indexes', 'indexes'
          ledger.ensure_indexes!
          @out.puts('indexes ensured')
        when 'verify'
          ledger.verify
          @out.puts('verified')
        when 'status'
          @out.puts(format_status(ledger.status))
        else
          return usage(1)
        end
        0
      end

      # Load YAML configuration from disk.
      def load_config(path)
        YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: false) || {}
      end

      # Format status for humans.
      def format_status(status)
        status.map { |key, value| "#{key}: #{value.inspect}" }.join("\n")
      end

      # Print usage information.
      def usage(code)
        @out.puts(<<~TEXT)
          Usage:
            whodunit-chronicles ledger prepare CONFIG
            whodunit-chronicles ledger migrate CONFIG
            whodunit-chronicles ledger ensure-indexes CONFIG
            whodunit-chronicles ledger verify CONFIG
            whodunit-chronicles ledger status CONFIG
        TEXT
        code
      end
    end
  end
end
