# Architecture

## Pattern

- Clean Architecture
- Repository Pattern
- Riverpod DI and state orchestration
- Drift for local persistence

## Layers

- Core:
  - Constants, services, db, shared utilities
- Features:
  - `data/` local datasources + repo impl
  - `domain/` entities + repository contracts + use-cases
  - `presentation/` pages + controllers + widgets

## Offline First Strategy

- SQLite is the source of truth.
- UI always reads from local DB streams.
- Future cloud sync can use an outbox table and sync engine.

## Performance Strategy

- DB indexes on barcode, product code, SKU, category, and transaction dates.
- Pagination-ready repositories.
- Lightweight widget tree and lazy list rendering.
- Cart state in memory + periodic persistence.
