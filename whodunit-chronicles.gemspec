# frozen_string_literal: true

require_relative "lib/whodunit/chronicles/version"

Gem::Specification.new do |spec|
  spec.name = "whodunit-chronicles"
  spec.version = Whodunit::Chronicles::VERSION
  spec.authors = ["Ken"]
  spec.email = ["ken@example.com"]

  spec.summary = "The complete historical record of your data"
  spec.description = "While Whodunit tracks who made changes, Chronicles captures " \
                     "what changed by streaming database events into comprehensive " \
                     "audit trails with zero Rails application overhead."
  spec.homepage = "https://github.com/whodunit-gem/whodunit-chronicles"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "dry-configurable", "~> 1.0"
  spec.add_dependency "dry-logger", "~> 1.0"

  # PostgreSQL dependencies
  spec.add_dependency "pg", "~> 1.5"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.4"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 2.25"
  spec.add_development_dependency "rubocop-performance", "~> 1.19"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "yard", "~> 0.9"
end