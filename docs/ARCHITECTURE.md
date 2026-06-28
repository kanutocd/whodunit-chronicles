# whodunit-chronicles Architecture

`whodunit-chronicles` is the canonical audit sink for the CDC ecosystem. It depends on `cdc-core`, implements `CDC::Core::Processor`, and consumes `CDC::Core::ChangeEvent`.

```text
CDC::Core::ChangeEvent
        |
        v
Chronicler
        |
        v
Immutable LedgerEntry
        |
        v
Ledger
```

## Runtime boundary

The runtime path only appends entries. It does not create tables, migrate schemas,
manage replication slots, schedule workers, or orchestrate concurrency.

## Operational boundary

The CLI owns ledger lifecycle operations such as prepare, migrate, index creation,
verification, and status.

## Core ledgers

The core gem includes only lightweight books:

- `MemoryLedger`
- `FileLedger`
- `SQLiteLedger`

Heavier storage targets such as PostgreSQL, MySQL, MongoDB, S3, Snowflake, and
PaperTrail-compatible shapes belong in extension gems.
