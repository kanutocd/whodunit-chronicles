# frozen_string_literal: true

module Whodunit
  module Chronicles
    # Base exception for whodunit-chronicles.
    class Error < StandardError; end

    # Base exception for ledger-related failures.
    class LedgerError < Error; end

    # Raised when an append operation fails before a result can be returned.
    class AppendError < LedgerError; end

    # Raised when ledger configuration cannot be built.
    class ConfigurationError < Error; end
  end
end
