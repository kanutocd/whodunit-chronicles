# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'coverage'
  Coverage.start(lines: true, branches: true)
  at_exit do
    result = Coverage.result
    root = File.expand_path('../lib', __dir__)
    report_dir = File.expand_path('../coverage', __dir__)
    FileUtils.mkdir_p(report_dir)

    line_total = 0
    line_covered = 0
    branch_total = 0
    branch_covered = 0
    misses = []

    result.each do |path, data|
      next unless path.start_with?(root)

      relative = path.delete_prefix("#{File.expand_path('..', __dir__)}/")
      data.fetch(:lines).each_with_index do |hits, index|
        next if hits.nil?

        line_total += 1
        if hits.positive?
          line_covered += 1
        else
          misses << "#{relative}:#{index + 1}: line not covered"
        end
      end

      data.fetch(:branches, {}).each do |branch, alternatives|
        alternatives.each do |alternative, hits|
          branch_total += 1
          if hits.positive?
            branch_covered += 1
          else
            branch_line = Array(branch).fetch(2, '?')
            misses << "#{relative}:#{branch_line}: branch #{Array(alternative).first} not covered"
          end
        end
      end
    end

    line_percent = line_total.zero? ? 100.0 : ((line_covered.to_f / line_total) * 100).round(2)
    branch_percent = branch_total.zero? ? 100.0 : ((branch_covered.to_f / branch_total) * 100).round(2)

    File.write(
      File.join(report_dir, 'coverage.txt'),
      <<~TEXT
        Line Coverage: #{format('%.2f', line_percent)}% (#{line_covered} / #{line_total})
        Branch Coverage: #{format('%.2f', branch_percent)}% (#{branch_covered} / #{branch_total})
      TEXT
    )

    puts "Line Coverage: #{format('%.2f', line_percent)}% (#{line_covered} / #{line_total})"
    puts "Branch Coverage: #{format('%.2f', branch_percent)}% (#{branch_covered} / #{branch_total})"

    next if misses.empty? && line_percent == 100.0 && branch_percent == 100.0

    File.write(File.join(report_dir, 'missing_coverage.txt'), "#{misses.join("\n")}\n")
    warn 'Coverage gate failed. Missing coverage written to coverage/missing_coverage.txt'
    exit 1
  end
end

cdc_core_path = ENV.fetch('CDC_CORE_PATH', nil)
$LOAD_PATH.unshift File.join(cdc_core_path, 'lib') if cdc_core_path && !cdc_core_path.empty?
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/autorun'
require 'whodunit-chronicles'

module LedgerEntryFixtures
  def sample_change_event(table: 'users', operation: :insert, old_values: nil, new_values: { id: 1, name: 'Alice' })
    CDC::Core::ChangeEvent.new(
      operation: operation,
      schema: 'public',
      table: table,
      old_values: old_values,
      new_values: new_values,
      primary_key: { id: 1 },
      transaction_id: 'tx-1',
      commit_lsn: '0/1',
      sequence_number: 1,
      occurred_at: Time.utc(2026, 1, 1, 0, 0, 0),
      metadata: { actor: { id: 42 } }
    )
  end

  def sample_entry
    Whodunit::Chronicles::LedgerEntry.from_change_event(
      sample_change_event,
      clock: Struct.new(:now).new(Time.utc(2026, 1, 1, 0, 0, 1))
    )
  end
end

Minitest::Test.include(LedgerEntryFixtures)
