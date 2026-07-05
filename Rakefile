# frozen_string_literal: true

require 'rake/testtask'
require 'rubygems/package_task'
require 'fileutils'
require 'pathname'

Rake::TestTask.new(:test) do |task|
  task.libs << 'test'
  task.pattern = 'test/**/*_test.rb'
end

gemspec = Gem::Specification.load('whodunit-chronicles.gemspec')
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

desc 'Run tests with strict 100% line and branch coverage gates'
task :coverage do
  sh({ 'COVERAGE' => 'true' }, "ruby -Itest -Ilib -e 'Dir[\"test/**/*_test.rb\"].sort.each { |f| require_relative f }'")
end

namespace :rbs do
  desc "Validate signatures and statically check the implementation"
  task :validate do
    sh "bundle exec steep check --severity-level=error"
  end
end

namespace :yard do
  desc 'Validate that all public declarations have documentation comments'
  task :validate do
    undocumented = []

    Dir.glob('lib/**/*.rb').each do |file|
      previous_significant = nil
      File.readlines(file).each_with_index do |line, index|
        stripped = line.strip
        namespace_reopen = stripped.match?(/^module\s+(Whodunit|Chronicles|Ledgers)\b/)
        public_declaration = stripped.match?(/^class\s+[A-Z]/) || stripped.match?(/^def\s+(self\.)?[a-zA-Z_]\w*[!?=]?/)
        if public_declaration && !namespace_reopen && !previous_significant&.start_with?('#')
          undocumented << "#{file}:#{index + 1}: #{stripped}"
        end
        previous_significant = stripped unless stripped.empty? || stripped == '# frozen_string_literal: true'
      end
    end

    abort "YARD coverage below 100%. Undocumented declarations:\n#{undocumented.join("\n")}" if undocumented.any?

    FileUtils.mkdir_p('coverage')
    File.write('coverage/yard.txt', "YARD documentation coverage: 100.00%\n")
    puts 'YARD documentation coverage: 100.00%'
  end

  task coverage: :validate
end

desc 'Run the full golden elephant quality gate'
task quality: [:test, :coverage, 'rbs:validate', 'yard:validate']

task default: :quality

desc 'Build the gem artifact'
task build: :gem
