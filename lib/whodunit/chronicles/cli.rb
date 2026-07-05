# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'errors'
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
        options = @argv.dup
        return usage(1) unless namespace == 'ledger' && command && config_path

        ledger = LedgerFactory.build(load_config(config_path))
        execute_ledger_command(ledger, command, options)
      rescue StandardError => e
        @err.puts(e.message)
        1
      end

      private

      # Execute a ledger lifecycle command.
      def execute_ledger_command(ledger, command, options)
        case command
        when 'prepare'
          return usage(1) unless options.empty?

          ensure_supported!(ledger, :prepare!)
          ledger.prepare!
          @out.puts('prepared')
        when 'migrate'
          return usage(1) unless options.empty?

          ensure_supported!(ledger, :migrate!)
          ledger.migrate!
          @out.puts('migrated')
        when 'ensure-indexes', 'indexes'
          return usage(1) unless options.empty?

          ensure_supported!(ledger, :ensure_indexes!)
          ledger.ensure_indexes!
          @out.puts('indexes ensured')
        when 'verify'
          return usage(1) unless options.empty?

          ensure_supported!(ledger, :verify)
          raise LedgerError, 'ledger verification failed' unless ledger.verify

          @out.puts('verified')
        when 'status'
          return usage(1) unless options.empty? || options == ['--json']

          ensure_supported!(ledger, :status)
          @out.puts(format_status(ledger.status, options))
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
      def format_status(status, options)
        return JSON.pretty_generate(status) if options == ['--json']

        status.map { |key, value| "#{key}: #{value.inspect}" }.join("\n")
      end

      # Ensure a ledger supports an operational method.
      def ensure_supported!(ledger, method_name)
        return true if ledger.respond_to?(method_name)

        raise LedgerError, "ledger does not support #{method_name}"
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
            whodunit-chronicles ledger status CONFIG --json
        TEXT
        code
      end
    end
  end
end
