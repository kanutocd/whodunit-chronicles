# frozen_string_literal: true

require 'test_helper'
require 'stringio'
require 'tmpdir'
require 'whodunit/chronicles/cli'

class CLITest < Minitest::Test
  def test_help_returns_success
    out = StringIO.new

    code = Whodunit::Chronicles::CLI.run(['help'], out: out, err: StringIO.new)

    assert_equal 0, code
    assert_includes out.string, 'ledger prepare'
  end

  def test_invalid_shape_returns_usage_error
    out = StringIO.new

    code = Whodunit::Chronicles::CLI.run(['wrong'], out: out, err: StringIO.new)

    assert_equal 1, code
    assert_includes out.string, 'Usage'
  end

  def test_prepare_file_ledger
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      path = File.join(dir, 'entries.ndjson')
      File.write(config, { ledger: { adapter: 'file', path: path } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'prepare', config], out: out, err: StringIO.new)

      assert_equal 0, code
      assert_equal "prepared\n", out.string
      assert File.file?(path)
    end
  end

  def test_migrate_file_ledger
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'file', path: File.join(dir, 'entries.ndjson') } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'migrate', config], out: out, err: StringIO.new)

      assert_equal 0, code
      assert_equal "migrated\n", out.string
    end
  end

  def test_indexes_file_ledger
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'file', path: File.join(dir, 'entries.ndjson') } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'indexes', config], out: out, err: StringIO.new)

      assert_equal 0, code
      assert_equal "indexes ensured\n", out.string
    end
  end

  def test_verify_file_ledger
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'file', path: File.join(dir, 'entries.ndjson') } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'verify', config], out: out, err: StringIO.new)

      assert_equal 0, code
      assert_equal "verified\n", out.string
    end
  end

  def test_status_file_ledger
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'file', path: File.join(dir, 'entries.ndjson') } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'status', config], out: out, err: StringIO.new)

      assert_equal 0, code
      assert_includes out.string, 'adapter'
    end
  end

  def test_unknown_command_returns_usage_error
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'memory' } }.to_yaml)
      out = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'unknown', config], out: out, err: StringIO.new)

      assert_equal 1, code
      assert_includes out.string, 'Usage'
    end
  end

  def test_configuration_error_returns_failure
    Dir.mktmpdir do |dir|
      config = File.join(dir, 'config.yml')
      File.write(config, { ledger: { adapter: 'unknown' } }.to_yaml)
      err = StringIO.new

      code = Whodunit::Chronicles::CLI.run(['ledger', 'status', config], out: StringIO.new, err: err)

      assert_equal 1, code
      assert_includes err.string, 'unsupported ledger adapter'
    end
  end
end
