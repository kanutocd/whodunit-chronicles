# 📚 Whodunit Chronicles

[![Gem Version](https://badge.fury.io/rb/whodunit-chronicles.svg)](https://badge.fury.io/rb/whodunit-chronicles)
[![CI](https://github.com/kanutocd/whodunit-chronicles/workflows/CI/badge.svg)](https://github.com/kanutocd/whodunit-chronicles/actions)
[![Coverage Status](https://codecov.io/gh/kanutocd/whodunit-chronicles/branch/main/graph/badge.svg)](https://codecov.io/gh/kanutocd/whodunit-chronicles)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.1.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **The complete historical record of your _Whodunit Dun Wat?_ data**

> **💡 Origin Story:** Chronicles is inspired by the challenge of streaming database changes for real-time analytics without impacting application performance. The concept proved so effective in a previous project that it became the foundation for this Ruby implementation.

While [Whodunit](https://github.com/kanutocd/whodunit) tracks _who_ made changes, **Chronicles** captures _what_ changed by streaming database events into comprehensive audit trails with **zero Rails application overhead**.

## ✨ Features

- **🚄 Zero-Latency Streaming**: PostgreSQL logical replication + MySQL/MariaDB binary log streaming
- **🔄 Zero Application Overhead**: No Rails callbacks or Active Record hooks required
- **🏗️ Database Agnostic**: Abstract adapter pattern supports PostgreSQL and MySQL/MariaDB
- **⚡ Thread-Safe**: Concurrent processing with configurable thread pools
- **🛡️ Resilient**: Built-in error handling, retry logic, and monitoring
- **📊 Complete Audit Trail**: Captures INSERT, UPDATE, DELETE with full before/after data
- **🧪 Code Coverage**: 94%+ test coverage with comprehensive error scenarios

## 🚀 Quick Start

### 🎯 Usage Scenarios

Chronicles excels at transforming database changes into business intelligence. Here are two common patterns:

#### 1. Basic Audit Trail Integration

---

Perfect for applications that need comprehensive change tracking alongside Whodunit's user attribution:

```ruby
# Basic setup for user activity tracking
class BasicProcessor < Whodunit::Chronicles::Processor
  def build_chronicles_record(change_event)
    super.tap do |record|
      # Add basic business context
      record[:change_category] = categorize_change(change_event)
      record[:business_impact] = assess_impact(change_event)
    end
  end

  private

  def categorize_change(change_event)
    case change_event.table_name
    when 'users' then 'user_management'
    when 'posts' then 'content'
    when 'comments' then 'engagement'
    else 'system'
    end
  end
end
```

**Use Case**: Blog platform tracking user posts and comments for community management and content moderation.

#### 2. Advanced Recruitment Analytics

Sophisticated business intelligence for talent acquisition platforms:

```ruby
# Advanced processor for recruitment metrics
class RecruitmentAnalyticsProcessor < Whodunit::Chronicles::Processor
  def build_chronicles_record(change_event)
    super.tap do |record|
      # Add recruitment-specific business metrics
      record[:recruitment_stage] = determine_stage(change_event)
      record[:funnel_position] = calculate_funnel_position(change_event)
      record[:time_to_hire_impact] = assess_time_impact(change_event)
      record[:cost_per_hire_impact] = calculate_cost_impact(change_event)

      # Campaign attribution
      record[:utm_source] = extract_utm_source(change_event)
      record[:campaign_id] = extract_campaign_id(change_event)

      # Quality metrics
      record[:candidate_quality_score] = assess_candidate_quality(change_event)
    end
  end

  def process(change_event)
    record = build_chronicles_record(change_event)
    store_audit_record(record)

    # Stream to analytics platforms
    stream_to_prometheus(record) if track_metrics?
    update_grafana_dashboard(record)
    trigger_real_time_alerts(record) if alert_worthy?(record)
  end

  private

  def determine_stage(change_event)
    return 'unknown' unless change_event.table_name == 'applications'

    case change_event.new_data&.dig('status')
    when 'submitted' then 'application'
    when 'screening', 'in_review' then 'screening'
    when 'interview_scheduled', 'interviewed' then 'interview'
    when 'offer_extended', 'offer_accepted' then 'offer'
    when 'hired' then 'hire'
    else 'unknown'
    end
  end

  def stream_to_prometheus(record)
    # Track key recruitment metrics
    RECRUITMENT_APPLICATIONS_TOTAL.increment(
      source: record[:utm_source],
      department: record.dig(:new_data, 'department')
    )

    if record[:action] == 'UPDATE' && status_changed_to_hired?(record)
      RECRUITMENT_HIRES_TOTAL.increment(
        source: record[:utm_source],
        time_to_hire: record[:time_to_hire_impact]
      )
    end
  end

  def update_grafana_dashboard(record)
    # Send time-series data for Grafana visualization
    InfluxDB.write_point('recruitment_events', {
      timestamp: record[:occurred_at],
      table: record[:table_name],
      action: record[:action],
      stage: record[:recruitment_stage],
      source: record[:utm_source],
      cost_impact: record[:cost_per_hire_impact],
      quality_score: record[:candidate_quality_score]
    })
  end
end
```

**Use Case**: Imagine a Spherical Cow Talent acquisition platform tracking candidate journey from application through hire, with real-time dashboards showing conversion rates, time-to-hire, cost-per-hire, and source effectiveness.

#### 📊 Visual Analytics Dashboard

The recruitment analytics processor creates comprehensive Grafana dashboards for executive reporting and operational insights:

<div align="center">

**Campaign Performance Analytics**
<a href="examples/images/campaign-performance-analytics.png" title="Click to view full size image">
<img src="examples/images/campaign-performance-analytics.png" width="300" />
</a>
_Track campaign ROI, cost-per-hire by channel, and conversion rates across marketing sources_

**Candidate Journey Analytics**
<a href="examples/images/candidate-journey-analytics.png" title="Click to view full size image">
<img src="examples/images/candidate-journey-analytics.png" width="300" />
</a>
_Monitor candidate engagement, funnel conversion rates, and application completion patterns_

**Recruitment Funnel Analytics**
<a href="examples/images/recruitment-funnel-analytics.png" title="Click to view full size image">
<img src="examples/images/recruitment-funnel-analytics.png" width="300" />
</a>
_Analyze hiring pipeline progression, department performance, and time-series trends_

</div>

These dashboards are automatically populated by Chronicles as candidates move through your hiring funnel, providing real-time visibility into recruitment performance without any manual data entry.

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

# Database Configuration

## PostgreSQL Configuration
Whodunit::Chronicles.configure do |config|
  config.adapter = :postgresql
  config.database_url = 'postgresql://localhost/myapp_production'
  config.audit_database_url = 'postgresql://localhost/myapp'
  config.publication_name = 'myapp_chronicles'
  config.replication_slot_name = 'myapp_chronicles_slot'
end

## MySQL/MariaDB Configuration
Whodunit::Chronicles.configure do |config|
  config.adapter = :mysql
  config.database_url = 'mysql://user:password@localhost/myapp_production'
  config.audit_database_url = 'mysql://user:password@localhost/myapp_audit'
  config.mysql_server_id = 1001  # Unique server ID for replication
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

Chronicles uses **PostgreSQL logical replication** and **MySQL/MariaDB binary log streaming** to capture database changes without impacting your application:

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

- **StreamAdapter**: Database-specific change streaming (PostgreSQL logical replication, MySQL/MariaDB binary log streaming)
- **ChangeEvent**: Unified change representation across adapters
- **Processor**: Transforms changes into searchable audit records
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

### Custom Processors for Analytics & Monitoring

**The real power of Chronicles** comes from creating custom processors tailored for your specific analytics needs. While Whodunit captures basic "who changed what," Chronicles lets you build sophisticated data pipelines for tools like **Grafana**, **DataDog**, or **Elasticsearch**.

Transform database changes into actionable business intelligence with features like:

- **25+ Custom Metrics**: Track business KPIs like conversion rates, time-to-hire, and cost-per-acquisition
- **Real-time Dashboards**: Stream data to Grafana for executive reporting and operational monitoring
- **Smart Alerting**: Trigger notifications based on business rules and thresholds
- **Multi-destination Streaming**: Send data simultaneously to multiple analytics platforms

#### Analytics-Focused Processor

```ruby
class AnalyticsProcessor < Whodunit::Chronicles::Processor
  def build_chronicles_record(change_event)
    super.tap do |record|
      # Add business metrics
      record[:business_impact] = calculate_business_impact(change_event)
      record[:user_segment] = determine_user_segment(change_event)
      record[:feature_flag] = current_feature_flags

      # Add performance metrics
      record[:change_size] = calculate_change_size(change_event)
      record[:peak_hours] = during_peak_hours?
      record[:geographic_region] = user_region(change_event)

      # Add time-series friendly fields for Grafana
      record[:hour_of_day] = Time.current.hour
      record[:day_of_week] = Time.current.wday
      record[:is_weekend] = weekend?

      # Custom tagging for filtering
      record[:tags] = generate_tags(change_event)
    end
  end

  private

  def calculate_business_impact(change_event)
    case change_event.table_name
    when 'orders' then 'revenue_critical'
    when 'users' then 'customer_critical'
    when 'products' then 'inventory_critical'
    else 'standard'
    end
  end

  def determine_user_segment(change_event)
    return 'anonymous' unless change_event.user_id

    # Look up user tier from your business logic
    User.find(change_event.user_id)&.tier || 'standard'
  end

  def generate_tags(change_event)
    tags = [change_event.action.downcase]
    tags << 'bulk_operation' if bulk_operation?(change_event)
    tags << 'api_driven' if api_request?
    tags << 'admin_action' if admin_user?(change_event.user_id)
    tags
  end
end
```

#### Grafana Dashboard Ready

```ruby
class GrafanaProcessor < Whodunit::Chronicles::Processor
  def build_chronicles_record(change_event)
    {
      # Core metrics for Grafana time series
      timestamp: change_event.occurred_at,
      table_name: change_event.table_name,
      action: change_event.action,

      # Numerical metrics for graphs
      records_affected: calculate_records_affected(change_event),
      change_magnitude: calculate_change_magnitude(change_event),
      user_session_duration: calculate_session_duration(change_event),

      # Categorical dimensions for filtering
      environment: Rails.env,
      application_version: app_version,
      database_instance: database_identifier,

      # Business KPIs
      revenue_impact: calculate_revenue_impact(change_event),
      customer_satisfaction_risk: assess_satisfaction_risk(change_event),

      # Performance indicators
      query_duration_ms: extract_query_duration(change_event),
      concurrent_users: current_concurrent_users,
      system_load: current_system_load
    }
  end
end
```

#### Real-Time Alerts Processor

```ruby
class AlertingProcessor < Whodunit::Chronicles::Processor
  def process(change_event)
    record = build_chronicles_record(change_event)

    # Store the audit record
    store_audit_record(record)

    # Real-time alerting logic
    send_alert(record) if alert_worthy?(record)

    # Stream to monitoring systems
    stream_to_datadog(record) if production?
    stream_to_grafana(record)
  end

  private

  def alert_worthy?(record)
    # Define your alerting criteria
    record[:business_impact] == 'revenue_critical' ||
    record[:records_affected] > 1000 ||
    record[:action] == 'DELETE' && record[:table_name] == 'orders'
  end

  def stream_to_grafana(record)
    # Send metrics to Grafana via InfluxDB/Prometheus
    InfluxDB.write_point("chronicles_events", record)
  end
end
```

#### Multiple Processor Pipeline

```ruby
# Chain multiple processors for different purposes
service = Whodunit::Chronicles::Service.new(
  adapter: Adapters::PostgreSQL.new,
  processor: CompositeProcessor.new([
    AnalyticsProcessor.new,     # For business intelligence
    AlertingProcessor.new,      # For real-time monitoring
    ComplianceProcessor.new,    # For regulatory requirements
    ArchivalProcessor.new       # For long-term storage
  ])
)
```

**Use Cases:**

- **📊 Business Intelligence**: Track user behavior patterns, feature adoption, revenue impact
- **🚨 Real-Time Monitoring**: Alert on suspicious activities, bulk operations, data anomalies
- **📈 Performance Analytics**: Database performance metrics, query optimization insights
- **🔍 Compliance Auditing**: Regulatory compliance, data governance, access patterns
- **💡 Product Analytics**: Feature usage, A/B testing data, user journey tracking

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

### Integration Testing

Test Chronicles with your Rails application using these patterns:

#### Basic Testing Pattern

```ruby
# Test basic Chronicles functionality
class ChroniclesIntegrationTest < ActiveSupport::TestCase
  def setup
    @service = Whodunit::Chronicles.service
    @service.setup!
    @service.start
  end

  def teardown
    @service.stop
    @service.teardown!
  end

  def test_audit_record_creation
    # Create a user (triggers Whodunit)
    user = User.create!(name: "John", email: "john@example.com")

    # Wait for Chronicles to process
    sleep 1

    # Check Chronicles audit record
    audit_record = AuditRecord.find_by(
      table_name: 'users',
      action: 'INSERT',
      record_id: { 'id' => user.id }
    )

    assert audit_record
    assert_equal 'INSERT', audit_record.action
    assert_equal user.name, audit_record.new_data['name']
  end
end
```

#### Advanced Analytics Testing

```ruby
# Test custom processor functionality
class RecruitmentAnalyticsTest < ActiveSupport::TestCase
  def setup
    @processor = RecruitmentAnalyticsProcessor.new
  end

  def test_recruitment_stage_determination
    change_event = create_change_event(
      table_name: 'applications',
      action: 'UPDATE',
      new_data: { 'status' => 'hired' }
    )

    record = @processor.build_chronicles_record(change_event)

    assert_equal 'hire', record[:recruitment_stage]
    assert record[:cost_per_hire_impact]
  end

  def test_metrics_streaming
    # Mock Prometheus and Grafana integrations
    assert_difference 'RECRUITMENT_HIRES_TOTAL.get' do
      @processor.stream_to_prometheus(hired_record)
    end
  end
end
```

### Unit Testing

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

We welcome contributions! Chronicles is designed to be extensible and work across different business domains.

1. Fork the repository
2. Set up your development environment:
   ```bash
   bundle install
   bundle exec rake test  # Ensure tests pass
   ```
3. Create your feature branch (`git checkout -b feature/amazing-feature`)
4. Make your changes with comprehensive tests
5. Test your changes:
   - Unit tests: `bundle exec rake test`
   - Code style: `bundle exec rubocop`
   - Security: `bundle exec bundler-audit check`
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request with a detailed description

### Contributing Custom Processors

We especially welcome custom processors for different business domains. Consider contributing processors for:

- E-commerce analytics (order tracking, inventory management)
- Financial services (transaction monitoring, compliance reporting)
- Healthcare (patient data tracking, regulatory compliance)
- Education (student progress, course analytics)
- SaaS metrics (user engagement, feature adoption)

## 📋 Requirements

- **Ruby**: 3.1.0 or higher
- **PostgreSQL**: 10.0 or higher (with logical replication enabled)
- **MySQL/MariaDB**: 5.6+ (with binary logging enabled)

## 🗺️ Roadmap

- [ ] **Prometheus Metrics**: Production monitoring integration (with complete codebase included in examples/)
- [ ] **Advanced Example Apps**: Real-world use cases with complete monitoring stack (with complete codebase included in examples/)
- [ ] **Custom Analytics Processors**: Business intelligence and real-time monitoring (with complete codebase included in examples/)
- [x] **MySQL/MariaDB Support**: MySQL/MariaDB databases binlog streaming adapter
- [ ] **Redis Streams**: Alternative lightweight streaming backend
- [ ] **Compression**: Optional audit record compression
- [ ] **Retention Policies**: Automated audit record cleanup
- [ ] **Web UI**: Management interface for monitoring and configuration

## 📚 Documentation

- **[API Documentation](https://kanutocd.github.io/whodunit-chronicles/)**
- **[Configuration Guide](docs/configuration-todo.md)**
- **[Architecture Deep Dive](docs/architecture-todo.md)**
- **[PostgreSQL Setup](docs/postgresql-setup-todo.md)**
- **[MySQL/MariaDB Setup](docs/mysql-setup.md)**
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
