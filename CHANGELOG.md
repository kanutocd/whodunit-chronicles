# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Comprehensive GitHub Actions CI/CD pipeline with multi-Ruby testing
- Automated security scanning with bundler-audit and CodeQL
- YARD documentation generation with GitHub Pages deployment
- Automated gem publishing workflow for tagged releases
- Structured issue and pull request templates for better contributor experience
- Dependabot configuration for automated dependency updates
- Security scanning dependencies (bundler-audit, brakeman)
- Comprehensive README with architecture diagrams and examples
- RuboCop configuration with relaxed metrics for test files

### Changed

- Updated dependencies to latest versions with security patches
- Improved RuboCop configuration to exclude test files from ClassLength limits
- Enhanced gemspec with proper metadata and security dependencies

## [0.1.0] - 2025-01-21

### Added

- **Core Architecture**: Complete zero-latency audit streaming implementation
- **PostgreSQL Adapter**: Logical replication streaming with WAL decoding
- **ChangeEvent System**: Unified change representation across database adapters
- **AuditProcessor**: Intelligent transformation of changes into audit records
- **Configuration Management**: Comprehensive settings with validation using dry-configurable
- **Service Orchestration**: Thread-safe service with error handling and retry logic
- **Abstract Adapter Pattern**: Extensible design supporting multiple database systems
- **User Attribution**: Automatic extraction of user information from creator/updater/deleter fields
- **Batch Processing**: Efficient bulk processing of audit records
- **Connection Management**: Robust database connection handling with retries
- **Error Handling**: Comprehensive error recovery and logging
- **Thread Safety**: Concurrent processing with thread pool management

### Technical Implementation

- **Modern Ruby Support**: Ruby 3.1+ with frozen string literals
- **Database Features**:
  - PostgreSQL logical replication with pgoutput plugin
  - Publication and replication slot management
  - WAL position tracking and resumption
  - Connection pooling and management
- **Event Processing**:
  - Real-time change capture at database level
  - Structured change events with metadata
  - Configurable table and schema filtering
  - Transaction ID and sequence number tracking
- **Audit Records**:
  - Complete before/after data capture
  - Calculated field-level changes
  - User attribution from standard columns
  - Timestamps and version tracking
  - JSON metadata storage

### Development & Testing

- **Test Coverage**: 94.3% code coverage (447/474 lines)
- **Testing Framework**: Minitest with shoulda-style assertions and mocha mocking
- **Test Suite**: 129 tests covering all components with comprehensive error scenarios
- **Code Quality**: RuboCop compliance with modern Ruby standards
- **Security**: bundler-audit integration for vulnerability scanning
- **Documentation**: Inline YARD documentation for all public APIs

### Dependencies

- **Core**: concurrent-ruby, dry-configurable, dry-logger, pg
- **Development**: minitest, rubocop, simplecov, yard
- **Testing**: mocha for mocking, pry for debugging
- **Security**: bundler-audit for vulnerability scanning

### Configuration Options

- Database connection URLs (source and audit)
- PostgreSQL publication and replication slot names
- Batch processing sizes and retry policies
- Table and schema inclusion/exclusion filters
- Logging levels and output configuration
- Thread pool and concurrency settings

### Performance Features

- **Zero Application Overhead**: No Rails callbacks or Active Record hooks
- **Efficient Streaming**: PostgreSQL logical replication optimization
- **Memory Management**: Streaming processing without dataset loading
- **Configurable Batching**: Tunable batch sizes for optimal throughput
- **Connection Reuse**: Persistent connections with automatic recovery
- **Background Processing**: Non-blocking operation with thread pools

### Production Ready Features

- **Monitoring**: Service status and health checking
- **Resilience**: Automatic retry logic with exponential backoff
- **Graceful Shutdown**: Clean service termination
- **Error Recovery**: Robust error handling with detailed logging
- **Position Tracking**: WAL position persistence for reliable resumption
- **Resource Management**: Bounded thread pools and memory usage
