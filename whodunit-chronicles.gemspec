# frozen_string_literal: true

require_relative 'lib/whodunit/chronicles/version'

Gem::Specification.new do |spec|
  spec.name = 'whodunit-chronicles'
  spec.version = Whodunit::Chronicles::VERSION
  spec.authors = ['Ken C. Demanawa', 'Spherical Cow']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'The complete historical record of your data'
  spec.description = 'While Whodunit tracks who made changes, Chronicles captures ' \
                     'what changed by streaming database events into comprehensive ' \
                     'audit trails with zero Rails application overhead.'
  spec.homepage = 'https://github.com/whodunit-gem/whodunit-chronicles'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core dependencies
  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'dry-configurable', '~> 1.0'
  spec.add_dependency 'dry-logger', '~> 1.0'

  # Database dependencies
  spec.add_dependency 'pg', '~> 1.5'
  # Driver for MySQL-compatible database
  spec.add_dependency 'trilogy', '~> 2.9'

  # Development dependencies
  spec.add_development_dependency 'kramdown', '~> 2.5'
  spec.add_development_dependency 'minitest', '~> 5.20'
  spec.add_development_dependency 'mocha', '~> 2.1'
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.6.0'
  spec.add_development_dependency 'rubocop', '~> 1.60'
  spec.add_development_dependency 'rubocop-minitest', '~> 0.34'
  spec.add_development_dependency 'rubocop-performance', '~> 1.19'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'simplecov-cobertura', '~> 3.0'
  spec.add_development_dependency 'yard', '~> 0.9'

  # Security scanning dependencies
  spec.add_development_dependency 'brakeman', '~> 6.0'
  spec.add_development_dependency 'bundler-audit', '~> 0.9'
end
