# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-01-28

### Added

- **MySQL/MariaDB Support**: Complete multi-database adapter architecture
  - MySQL adapter using trilogy gem for high-performance connections
  - Binary log streaming support for MySQL change capture
  - Cross-database compatibility testing
- **Enhanced Testing Suite**: Comprehensive test coverage improvements
  - New test files: `table_test.rb`, `connection_test.rb`, `persistence_test.rb`
  - Enhanced PostgreSQL adapter tests with connection and replication scenarios
  - Increased line coverage from 91.28% to 97.29% (+6.01 percentage points)
  - 227 tests with 552 assertions providing robust validation
- **Ruby 3.4+ Compatibility**: Forward compatibility improvements
  - Added `bigdecimal` dependency for Ruby 3.4+ support
  - Explicit dependency management for removed stdlib components
- **CI/CD Enhancements**: Improved automation and quality gates
  - Matrix testing across PostgreSQL and MySQL databases
  - Enhanced MySQL integration testing with proper connection handling
  - Security scanning integration and automated dependency updates

### Changed

- **Architecture Refactoring**: Modular component extraction
  - Extracted AuditProcessor into separate, focused components
  - Improved service layer with multi-adapter support patterns
  - Enhanced configuration system supporting both PostgreSQL and MySQL
- **Database Adapter Pattern**: Extensible multi-database support
  - Abstract adapter base class for consistent interface
  - Database-specific implementations with optimized performance
  - Unified change event system across different database types
- **Test Infrastructure**: Comprehensive testing improvements
  - Enhanced mock-based testing for complex database operations
  - Improved test organization with better separation of concerns
  - Integration test scenarios for real-world usage patterns

### Fixed

- **MySQL CI Integration**: Resolved connection and setup issues
  - Fixed MySQL container configuration and health checks  
  - Improved database readiness detection and timeout handling
  - Enhanced error reporting and debugging for CI environments
- **Dependency Management**: Ruby version compatibility
  - Added explicit `bigdecimal ~> 3.1` dependency for Ruby 3.4+
  - Resolved trilogy gem loading issues in newer Ruby versions
  - Improved gem specification with proper version constraints

### Technical Improvements

- **Code Coverage**: Significant testing improvements
  - Line coverage: 97.29% (647/665 lines covered)
  - Branch coverage: 83.6% (158/189 branches covered)
  - Comprehensive unit tests for all core modules
- **Performance Optimizations**: Multi-adapter efficiency
  - Database-specific SQL generation and parameter binding
  - Optimized connection management across different adapters
  - Efficient batch processing for both PostgreSQL and MySQL
- **Error Handling**: Enhanced resilience and debugging
  - Improved error messages and stack trace reporting
  - Better handling of database-specific error conditions
  - Enhanced logging for troubleshooting and monitoring

### Development Experience

- **Documentation**: Enhanced developer resources
  - Updated README with MySQL/MariaDB configuration examples
  - Improved inline documentation for multi-adapter usage
  - Better error messages and troubleshooting guides
- **Testing Framework**: Improved development workflow
  - Faster test execution with better mock strategies
  - More reliable CI/CD pipeline with matrix testing
  - Enhanced debugging capabilities for test failures

## [0.1.0] - 2025-01-21

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
- **Processor**: Intelligent transformation of changes into audit records
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
