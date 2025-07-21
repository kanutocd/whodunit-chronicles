# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'whodunit/chronicles'
require 'minitest/autorun'
require 'minitest/pride'
require 'mocha/minitest'

module Whodunit
  module Chronicles
    # Test helpers for Chronicles testing
    module TestHelpers
      def setup
        super
        # Reset configuration for each test - just configure defaults
        Chronicles.configure do |config|
          config.database_url = nil
          config.audit_database_url = nil
          config.adapter = :postgresql
          config.publication_name = 'whodunit_chronicles'
          config.replication_slot_name = 'whodunit_chronicles_slot'
          config.batch_size = 100
          config.max_retry_attempts = 3
          config.retry_delay = 5
        end
      end

      def create_change_event(action: 'INSERT', **options)
        defaults = {
          table_name: 'users',
          primary_key: { 'id' => 1 },
          timestamp: Time.now,
        }

        case action
        when 'INSERT'
          defaults[:new_data] = { 'id' => 1, 'name' => 'Ken', 'email' => 'spherical.cow@example.com' }
        when 'UPDATE'
          defaults[:old_data] = { 'id' => 1, 'name' => 'Ken', 'email' => 'spherical.cow@example.com' }
          defaults[:new_data] = { 'id' => 1, 'name' => 'Sophia', 'email' => 'sophia@example.com' }
        when 'DELETE'
          defaults[:old_data] = { 'id' => 1, 'name' => 'Sophia', 'email' => 'sophia@example.com' }
        end

        ChangeEvent.new(**defaults, action: action, **options)
      end

      def mock_logger
        logger = Object.new
        def logger.method_missing(_method, *_args, **_kwargs)
          # Stub all log levels
          nil
        end

        def logger.respond_to_missing?(_method, _include_private = false)
          true
        end

        logger
      end
    end
  end
end

# Include test helpers in all test classes
module Minitest
  class Test
    include Whodunit::Chronicles::TestHelpers
  end
end
