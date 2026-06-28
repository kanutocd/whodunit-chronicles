# frozen_string_literal: true

require 'cdc_core'

require_relative 'chronicles/version'
require_relative 'chronicles/errors'
require_relative 'chronicles/ledger'
require_relative 'chronicles/ledger_entry'
require_relative 'chronicles/chronicler'
require_relative 'chronicles/ledgers/memory_ledger'
require_relative 'chronicles/ledgers/file_ledger'
require_relative 'chronicles/ledgers/sqlite_ledger'
require_relative 'chronicles/ledger_factory'
require_relative 'chronicles/cli'

# Namespace for lightweight attribution and audit ecosystem libraries.
module Whodunit
  # Canonical CDC audit sink namespace.
  module Chronicles
  end
end
