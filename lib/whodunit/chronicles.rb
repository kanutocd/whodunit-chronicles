# frozen_string_literal: true

require 'concurrent-ruby'
require 'dry/configurable'
require 'dry/logger'

require_relative 'chronicles/version'
require_relative 'chronicles/configuration'
require_relative 'chronicles/change_event'
require_relative 'chronicles/stream_adapter'
require_relative 'chronicles/audit_processor'
require_relative 'chronicles/service'

# Adapters
require_relative 'chronicles/adapters/postgresql'

module Whodunit
  # Chronicles - The complete historical record of `whodunit did what?` data
  #
  # While Whodunit tracks who made changes, Chronicles captures what changed
  # by streaming database events into comprehensive audit trails with zero
  # Rails application overhead.
  module Chronicles
    extend Dry::Configurable

    # Configuration settings
    setting :logger, default: Dry::Logger.new
    setting :database_url, default: ENV.fetch('DATABASE_URL', nil)
    setting :audit_database_url, default: ENV.fetch('AUDIT_DATABASE_URL', nil)
    setting :adapter, default: :postgresql
    setting :publication_name, default: 'whodunit_audit'
    setting :replication_slot_name, default: 'whodunit_audit_slot'
    setting :batch_size, default: 100
    setting :max_retry_attempts, default: 3
    setting :retry_delay, default: 5

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AdapterError < Error; end
    class ReplicationError < Error; end

    # Configure Chronicles
    #
    # @example
    #   Whodunit::Chronicles.configure do |config|
    #     config.database_url = "postgresql://localhost/myapp"
    #     config.audit_database_url = "postgresql://localhost/myapp_audit"
    #     config.adapter = :postgresql
    #   end
    def self.configure
      yield(config) if block_given?
      config
    end

    # Get the configured logger
    #
    # @return [Dry::Logger]
    def self.logger
      config.logger
    end

    # Start the audit streaming service
    #
    # @return [Service]
    def self.start
      Service.new.start
    end
  end
end
