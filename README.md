# whodunit-chronicles

`whodunit-chronicles` is the minimal audit sink for the Ruby CDC ecosystem. It has a runtime dependency on `cdc-core` and consumes `CDC::Core::ChangeEvent` directly.

A `Chronicler` writes immutable `LedgerEntry` objects into any object that implements the `Ledger` contract.

```text
CDC::Core::ChangeEvent
        ↓
Whodunit::Chronicles::Chronicler
        ↓
Whodunit::Chronicles::LedgerEntry
        ↓
Ledger
```

## Core boundary

Core Chronicles owns:

- `cdc-core` processor integration

- `Chronicler`
- immutable `LedgerEntry`
- `Ledger` contract
- `MemoryLedger`
- `FileLedger`
- `SQLiteLedger`
- ledger lifecycle CLI

Core Chronicles does not own heavyweight storage integrations such as PostgreSQL, MySQL, Oracle, MongoDB, S3, Snowflake, Glacier, Mixpanel, or ClickHouse. Those belong in extension gems that implement the `Ledger` contract.

## Runtime usage

```ruby
ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: "chronicles.db")
chronicler = Whodunit::Chronicles::Chronicler.new(ledger: ledger, prepare: false)

chronicler.process(change_event) # change_event is CDC::Core::ChangeEvent
```

The runtime hot path is intentionally small:

```ruby
entry = Whodunit::Chronicles::LedgerEntry.from_change_event(event)
ledger.append(entry)
```

## Ledger contract

Required:

```ruby
ledger.append(entry)
```

Optional operational capabilities:

```ruby
ledger.prepare!
ledger.migrate!
ledger.ensure_indexes!
ledger.verify
ledger.status
ledger.partition_for(entry)
```

## Built-in ledgers

### MemoryLedger

For tests, examples, and short-lived scripts.

```ruby
ledger = Whodunit::Chronicles::Ledgers::MemoryLedger.new
```

### FileLedger

Append-only newline-delimited JSON file.

```ruby
ledger = Whodunit::Chronicles::Ledgers::FileLedger.new(path: "chronicles.ndjson")
ledger.prepare!
```

### SQLiteLedger

Embedded durable local ledger.

```ruby
ledger = Whodunit::Chronicles::Ledgers::SQLiteLedger.new(path: "chronicles.db")
ledger.prepare!
ledger.ensure_indexes!
```

`SQLiteLedger` depends on the `sqlite3` gem. Tests and advanced users may inject a compatible connection.

`ensure_indexes!` creates a unique index on `event_id`. Appending the same event more than once is not idempotent: SQLite rejects the duplicate row, and `SQLiteLedger#append` raises `Whodunit::Chronicles::AppendError`.

## CLI

Ledger evolution is operational work, similar to `db:migrate`. The gem consumer decides when to run it.

```bash
whodunit-chronicles ledger prepare config.yml
whodunit-chronicles ledger migrate config.yml
whodunit-chronicles ledger ensure-indexes config.yml
whodunit-chronicles ledger verify config.yml
whodunit-chronicles ledger status config.yml
```

Example configs:

```yaml
ledger:
  adapter: memory
```

```yaml
ledger:
  adapter: file
  path: chronicles.ndjson
```

```yaml
ledger:
  adapter: sqlite
  path: chronicles.db
  table_name: whodunit_chronicles_entries
```

Status can be printed as human-readable lines or JSON:

```bash
whodunit-chronicles ledger status config.yml
whodunit-chronicles ledger status config.yml --json
```

## Extension direction

Future storage books should be separate ledgers:

```text
whodunit-chronicles-postgres
whodunit-chronicles-mysql
whodunit-chronicles-mongo
whodunit-chronicles-s3
whodunit-chronicles-snowflake
whodunit-chronicles-paper_trail
```

Each extension implements the same ledger contract.
