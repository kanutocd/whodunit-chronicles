# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'whodunit/chronicles/ledgers/file_ledger'

class FileLedgerTest < Minitest::Test
  def test_prepare_creates_parent_directory_and_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'nested', 'entries.ndjson')
      ledger = Whodunit::Chronicles::Ledgers::FileLedger.new(path: path)

      assert_same ledger, ledger.prepare!
      assert File.file?(path)
    end
  end

  def test_append_writes_one_json_line_and_entries_reads_it
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'entries.ndjson')
      ledger = Whodunit::Chronicles::Ledgers::FileLedger.new(path: path).prepare!
      entry = sample_entry

      assert_same entry, ledger.append(entry)
      assert_equal 1, ledger.entries.length
      assert_equal entry.event_id, ledger.entries.first.fetch('event_id')
    end
  end

  def test_entries_returns_empty_array_when_file_does_not_exist
    Dir.mktmpdir do |dir|
      ledger = Whodunit::Chronicles::Ledgers::FileLedger.new(path: File.join(dir, 'missing.ndjson'))

      assert_equal [], ledger.entries
    end
  end
end

class FileLedgerCurrentDirectoryTest < Minitest::Test
  def test_prepare_file_in_current_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        ledger = Whodunit::Chronicles::Ledgers::FileLedger.new(path: 'entries.ndjson')

        ledger.prepare!

        assert File.file?('entries.ndjson')
      end
    end
  end
end
