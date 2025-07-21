# 📚 Whodunit Chronicles

[![Gem Version](https://badge.fury.io/rb/whodunit-chronicles.svg)](https://badge.fury.io/rb/whodunit-chronicles)
[![CI](https://github.com/kanutocd/whodunit-chronicles/workflows/CI/badge.svg)](https://github.com/kanutocd/whodunit-chronicles/actions)
[![Coverage Status](https://codecov.io/gh/kanutocd/whodunit-chronicles/branch/main/graph/badge.svg)](https://codecov.io/gh/kanutocd/whodunit-chronicles)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.1.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **The complete historical record of your _Whodunit Dun Wat?_ data**

While [Whodunit](https://github.com/kanutocd/whodunit) tracks _who_ made changes, **Chronicles** captures _what_ changed by streaming database events into comprehensive audit trails with **zero Rails application overhead**.

## ✨ Features

- **🚄 Zero-Latency Streaming**: PostgreSQL logical replication
- **🔄 Zero Application Overhead**: No Rails callbacks or Active Record hooks required
- **🏗️ Database Agnostic**: Abstract adapter pattern supports PostgreSQL (TODO: MySQL/MariaDB support)
- **⚡ Thread-Safe**: Concurrent processing with configurable thread pools
- **🛡️ Resilient**: Built-in error handling, retry logic, and monitoring
- **📊 Complete Audit Trail**: Captures INSERT, UPDATE, DELETE with full before/after data
- **🧪 VERY Soon to be Production Ready**: 94%+ test coverage with comprehensive error scenarios

## 🚀 Quick Start

### Installation

Add to your Gemfile:

```ruby
gem 'whodunit-chronicles'
```

Or install directly:

```bash
gem install whodunit-chronicles
```

### Basic Usage

```ruby
require 'whodunit/chronicles'

# PostgreSQL Configuration
Whodunit::Chronicles.configure do |config|
  config.adapter = :postgresql
  config.database_url = 'postgresql://localhost/myapp_production'
  config.audit_database_url = 'postgresql://localhost/myapp'
  config.publication_name = 'myapp_chronicles'
  config.replication_slot_name = 'myapp_chronicles_slot'
end

# Create and start the service
service = Whodunit::Chronicles.service
service.setup!  # Create publication/replication setup
service.start   # Begin streaming changes

# Service runs in background threads
sleep 10

# Stop gracefully
service.stop
service.teardown!  # Clean up database objects
```

## 🏗️ Architecture

Chronicles uses **PostgreSQL logical replication** (TODO: **MySQL/MariaDB binary log streaming**) to capture database changes without impacting your application:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │    │    Chronicles    │    │   Audit Store   │
│   Database      │───▶│     Service      │───▶│   Database      │
│                 │    │                  │    │                 │
│ • Users         │    │ • Stream Adapter │    │ • audit_records │
│ • Posts         │    │ • Event Parser   │    │ • Searchable    │
│ • Comments      │    │ • Audit Builder  │    │ • Reportable    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                       │
        │              ┌────────▼────────┐
        │              │  PostgreSQL     │
        └──────────────│  Logical        │
                       │  Replication    │
                       └─────────────────┘
```

### Core Components

- **StreamAdapter**: Database-specific change streaming (PostgreSQL, MySQL/MariaDB)
- **ChangeEvent**: Unified change representation across adapters
- **AuditProcessor**: Transforms changes into searchable audit records
- **Service**: Orchestrates streaming with error handling and retry logic

## ⚙️ Configuration

```ruby
Whodunit::Chronicles.configure do |config|
  # Database connections
  config.database_url = ENV['DATABASE_URL']
  config.audit_database_url = ENV['AUDIT_DATABASE_URL']

  # Database adapter (postgresql, mysql, mariadb)
  config.adapter = :postgresql

  # PostgreSQL-specific settings
  config.publication_name = 'whodunit_chronicles'
  config.replication_slot_name = 'whodunit_chronicles_slot'

  # Performance tuning
  config.batch_size = 1000
  config.max_retry_attempts = 5
  config.retry_delay = 10

  # Table filtering
  config.include_tables = %w[users posts comments]
  config.exclude_tables = %w[sessions temp_data]
  config.include_schemas = %w[public app]
  config.exclude_schemas = %w[information_schema pg_catalog]
end
```

## 📊 Audit Records

Chronicles creates structured audit records for each database change:

```ruby
{
  id: 123,
  table_name: "users",
  schema_name: "public",
  record_id: { "id" => 456 },
  action: "UPDATE",
  old_data: { "id" => 456, "email" => "old@example.com", "name" => "Old Name" },
  new_data: { "id" => 456, "email" => "new@example.com", "name" => "New Name" },
  changes: { "email" => ["old@example.com", "new@example.com"] },
  user_id: 789,           # From creator_id/updater_id/deleter_id columns
  user_type: "User",
  transaction_id: "tx_abc123",
  sequence_number: 42,
  occurred_at: 2025-01-21 10:30:00 UTC,
  created_at: 2025-01-21 10:30:01 UTC,
  metadata: {
    table_schema: "public",
    qualified_table_name: "public.users",
    changed_columns: ["email"],
    chronicles_version: "0.1.0"
  }
}
```

## 🔧 Advanced Usage

### Custom Audit Processing

```ruby
class MyCustomProcessor < Whodunit::Chronicles::AuditProcessor
  def build_chronicles_record(change_event)
    super.tap do |record|
      record[:custom_field] = extract_custom_data(change_event)
      record[:environment] = Rails.env
    end
  end

  private

  def extract_custom_data(change_event)
    # Your custom logic here
  end
end

# Use custom processor
service = Whodunit::Chronicles::Service.new(
  processor: MyCustomProcessor.new
)
```

### Service Monitoring

```ruby
service = Whodunit::Chronicles.service

# Check service status
status = service.status
puts "Running: #{status[:running]}"
puts "Adapter Position: #{status[:adapter_position]}"
puts "Retry Count: #{status[:retry_count]}"
puts "Active Threads: #{status[:executor_status][:active_count]}"

# Monitor in production
Thread.new do
  loop do
    status = service.status
    Rails.logger.info "Chronicles Status: #{status}"
    sleep 60
  end
end
```

## 🧪 Testing

Chronicles includes comprehensive test coverage:

```bash
# Run test suite
bundle exec rake test

# Run with coverage
bundle exec rake test
open coverage/index.html

# Security scanning
bundle exec bundler-audit check
bundle exec brakeman
```

## 📈 Performance

- **Minimal Overhead**: No Rails callback performance impact
- **Efficient Streaming**: PostgreSQL logical replication is highly optimized
- **Configurable Batching**: Process changes in configurable batch sizes
- **Thread Pool**: Concurrent processing with bounded resource usage
- **Memory Efficient**: Streaming processing without loading full datasets

## 🛡️ Security

- **Dependency Scanning**: Automated bundler-audit checks
- **Code Analysis**: GitHub CodeQL integration
- **Vulnerability Monitoring**: Weekly security scans
- **Safe Defaults**: Secure configuration out of the box

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Ensure tests pass (`bundle exec rake test`)
5. Ensure RuboCop passes (`bundle exec rubocop`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📋 Requirements

- **Ruby**: 3.1.0 or higher
- **PostgreSQL**: 10.0 or higher (with logical replication enabled)

## 🗺️ Roadmap

- [ ] **MySQL/MariaDB Support**: MySQL/MariaDB databases binlog streaming adapter
- [ ] **Redis Streams**: Alternative lightweight streaming backend
- [ ] **Compression**: Optional audit record compression
- [ ] **Retention Policies**: Automated audit record cleanup
- [ ] **Web UI**: Management interface for monitoring and configuration
- [ ] **Prometheus Metrics**: Production monitoring integration

## 📚 Documentation

- **[API Documentation](https://kanutocd.github.io/whodunit-chronicles/)**
- **[Configuration Guide](docs/configuration-todo.md)**
- **[Architecture Deep Dive](docs/architecture-todo.md)**
- **[PostgreSQL Setup](docs/postgresql-setup-todo.md)**
- **[Production Deployment](docs/production-todo.md)**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **PostgreSQL Team**: For excellent logical replication functionality
- **Ruby Community**: For amazing gems and tools that make this possible

---

<div align="center">

**[⭐ Star us on GitHub](https://github.com/kanutocd/whodunit-chronicles)** • **[🐛 Report Bug](https://github.com/kanutocd/whodunit-chronicles/issues)** • **[💡 Request Feature](https://github.com/kanutocd/whodunit-chronicles/issues)**

Made with ❤️ by a Spherical Cow

</div>
