# Pocket POS

Production-ready, lightweight, offline-first Kirana POS built with Flutter + Drift SQLite + Riverpod.

## Current Scope

- Phase 1 implemented:
  - Authentication
  - Category management
  - Product management
  - Inventory transactions
  - POS billing with multi-cart
- Phase 2 implemented:
  - Supplier management
  - Purchase management
  - Customer management
  - Advanced multi-cart operations (hold/resume/rename)
- Phase 3 implemented:
  - Credit/Udhar ledger
  - Reporting with CSV export
  - Expense management with CSV export
- Phase 4-5 architecture skeleton is included and ready for expansion.

## Highlights

- Offline-first local SQLite (Drift)
- Clean Architecture + Repository pattern
- Riverpod dependency injection and state management
- Role-based access model
- 50k product-friendly indexed schema
- Multi-cart billing model
- Receipt PDF service and printer-ready interfaces

## Quick Start

1. Install Flutter stable and platform toolchains.
2. Run:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

3. Default login users are seeded via SQL file in `tool/seed_data.sql`.

## Project Structure

See `docs/INSTALLATION_GUIDE.md` and `docs/ARCHITECTURE.md`.

## Main branch test