# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../ledger'

module Whodunit
  module Chronicles
    module Ledgers
      # Append-only newline-delimited JSON ledger for simple durable local storage.
      class FileLedger < Ledger
        # @return [String] path to the NDJSON ledger file
        attr_reader :path

        # Create a file-backed ledger.
        #
        # @param path [String] path to the NDJSON ledger file
        def initialize(path:)
          @path = path.to_s
        end

        # Ensure the parent directory and ledger file exist.
        #
        # @return [FileLedger] this ledger
        def prepare!
          directory = File.dirname(path)
          FileUtils.mkdir_p(directory) unless directory == '.'
          FileUtils.touch(path)
          self
        end

        # Append one entry as one JSON line.
        #
        # @param entry [LedgerEntry] entry to append
        # @return [LedgerEntry] appended entry
        def append(entry)
          File.open(path, 'ab') do |file|
            file.flock(File::LOCK_EX)
            file.write(JSON.generate(entry.to_h))
            file.write("\n")
          end
          entry
        end

        # Read all entries from the file as hashes.
        #
        # @return [Array<Hash>] decoded ledger lines
        def entries
          return [] unless File.exist?(path)

          File.readlines(path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
        end
      end
    end
  end
end
