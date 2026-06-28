# frozen_string_literal: true

require_relative 'lib/whodunit/chronicles/version'

Gem::Specification.new do |spec|
  spec.name = 'whodunit-chronicles'
  spec.version = Whodunit::Chronicles::VERSION
  spec.authors = ['Ken C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'A minimal CDC audit sink for immutable ledger entries'
  spec.description = <<~DESC
    Whodunit Chronicles records CDC change events as immutable ledger entries.
    It provides a tiny Chronicler processor, a Ledger abstraction,
    and simple ledger implementations without owning replication, runtime execution, or orchestration.
  DESC
  spec.homepage = 'https://github.com/kanutocd/whodunit-chronicles'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir.glob('{lib,sig,exe}/**/*') + %w[README.md CHANGELOG.md LICENSE]
  end
  spec.bindir = 'exe'
  spec.executables = ['whodunit-chronicles']
  spec.require_paths = ['lib']

  spec.add_dependency 'cdc-core', '>= 0.1'
end
