# Changelog

## Unreleased

## 0.4.0

- Rebuilt as a minimal CDC audit sink.
- Added `Chronicler` as a `CDC::Core::Processor`.
- Added runtime dependency on `cdc-core`.
- Added immutable `LedgerEntry`.
- Added `Ledger` base contract.
- Added `MemoryLedger`.
- Added `FileLedger`.
- Added `SQLiteLedger`.
- Added ledger lifecycle CLI.
- Added RBS signatures.
- Added 100% code coverage and 100% YARD coverage gates.
- Added runtime dependency on `sqlite3` for built-in SQLite ledger support.
- Added real SQLite integration coverage for persistence, custom tables, status counts, and duplicate event IDs.
- Clarified SQLite duplicate append behavior: duplicate `event_id` values raise `Whodunit::Chronicles::AppendError`.
- Added JSON status output and stricter option validation to the ledger lifecycle CLI.
- Improved CLI errors for malformed configuration, missing required ledger options, unsupported lifecycle methods, and failed verification.
- Completed the Steep-backed RBS quality gate.
- Added GitHub Actions workflows for generated YARD documentation and tagged RubyGems releases.
