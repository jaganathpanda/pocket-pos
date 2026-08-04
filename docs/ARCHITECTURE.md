# Architecture

Pocket POS is a **multi-tenant, offline-first** Flutter app backed by **Cloud Firestore** and
**Firebase Auth**, running on Web and Android from one codebase. This document describes how it's
actually implemented today.

> History: the app began as a single-store, offline **Drift/SQLite** app and was migrated to a
> Firebase SaaS. The Drift **schema + generated model classes are retained and reused as
> Firestore DTOs**, but Firestore is now the system of record. A few legacy Drift references may
> remain in non-critical paths.

---

## 1. Layers

Per-feature, under `lib/features/<feature>/`:

- **presentation/** — Flutter widgets + Riverpod controllers (`StateNotifier` / `StreamProvider`).
- **domain/** — abstract repository interfaces + models (models are Drift row classes).
- **data/** — `Firestore<Feature>Repository` implementing the domain interface.

Cross-cutting code lives in `lib/core/`:

- `di/providers.dart` — **all** Riverpod providers; the single wiring point. Each repo provider
  builds a Firestore implementation scoped to the active tenant.
- `firestore/` — tenant scoping, id generation, document↔model mappers, offline-safe helpers,
  demo-catalog seeder.
- `database/` — Drift schema + generated code + per-industry demo data.
- `services/` — e.g. `ReceiptPdfService`.
- `app/` — `MaterialApp` + `go_router` (routes, auth redirects, responsive shell nav).

---

## 2. Data model (Firestore)

Everything tenant-owned is namespaced under a store document:

```
stores/{storeId}/
  categories/{id}
  products/{id}
  inventory/{id}            # one row per (product, warehouse)
  warehouses/{id}
  carts/{id}                # status: active | hold | completed
  cart_items/{id}
  sales/{id}
  sale_items/{id}
  payments/{id}
  customers/{id}
  suppliers/{id}
  purchases/{id} / purchase_items/{id}
  staffs/{id} / staff_attendances/{id} / staff_payrolls/{id} / staff_salary_payments/{id}
  settings/{inventory|demo|…}
  users/{uid}               # store directory: username, role, posCounterId

# top-level (not tenant-scoped)
stores/{storeId}            # name, ownerUid, ownerUsername, email, status, businessType
user_store_index/{uid}      # uid -> storeId  (session restore)
platform_admins/{uid}       # presence = this user is a platform admin
email_index/{email}         # one-email-one-store reservation
```

**Integer-id-as-document-id.** Docs are stored under a numeric id (`core/firestore/firestore_ids.dart`)
so the reused Drift models (which key on `int id`) map 1:1. Ids are
`millisecondsSinceEpoch * 1000 + counter`, kept **below 2^53** so they're exact on Flutter web
(where Dart ints are JS doubles).

**Tenant scoping.** `core/firestore/store_scope.dart#storeCollection(db, storeId, name)` is the
only place the `stores/{storeId}/…` path is built. `activeStoreIdProvider` yields the current
tenant; every repo provider injects it.

**Mappers.** `core/firestore/firestore_mappers.dart` converts documents to the Drift model
classes and tolerates missing/`serverTimestamp`-pending fields (falls back to `DateTime.now()`),
so offline-written docs (whose server timestamps are still null locally) never crash the UI.

---

## 3. Offline-first strategy

Firestore **offline persistence** is enabled once in `main.dart`
(`Settings(persistenceEnabled: true, cacheSizeBytes: UNLIMITED)`). The subtle parts:

### Writes — never await server acknowledgement
A Firestore write applies to the **local cache synchronously** (so `snapshots()` streams and
subsequent cache reads see it immediately), but the returned `Future` **only completes on server
ack** — which never happens while offline. Awaiting it would hang the UI (New Cart wouldn't
appear, the add-item dialog wouldn't close, checkout wouldn't finish) until reconnect.

So terminal writes are **fire-and-forget**:
- `core/firestore/store_scope.dart#queueWrite(Future)` — issues the write, swallows/logs late
  errors, does **not** await. Used by repos (e.g. customer `createOrUpdate`).
- The sales repo has an equivalent private `_write(...)` used by `createCart`, `addItem`,
  `updateItemQuantity`, `removeItem`, `checkout` (batch commit), `recordCreditPayment`, and the
  cart mutators.

Reads that must happen *before* a write (product lookup, stock check) are still awaited — they
resolve from cache offline.

### Reads — cache-safe document fetch
A one-time `DocumentReference.get()` **throws `unavailable`** offline if that exact doc isn't in
the cache; a `Query.get()`, however, is always served from cache. So
`store_scope.dart#cacheSafeDoc(collection, id)` tries `doc().get()` and, on `unavailable`, falls
back to a `where(FieldPath.documentId == id)` **query**. Used for cart/product/customer/sale/
inventory-mode single-doc reads in the billing path.

### Keeping caches warm
The offline billing path resolves the default warehouse and reads stock. A cashier never opens
the Inventory/Warehouse screens, so those collections wouldn't be cached. The **app shell**
(`lib/app/router.dart` `_AppShell`) therefore holds `warehousesProvider` and `inventoryProvider`
(plus `inventoryModeProvider`) alive for the whole session so their caches stay warm.

### Net effect
Bill and check out fully offline; writes queue in Firestore's durable mutation queue and sync
automatically on reconnect. Requires an initial online sign-in to prime the cache (standard for
offline-first).

---

## 4. Auth & registration flows

Implemented in `features/store/data/store_auth_service.dart` + `presentation/store_auth_controller.dart`.

**Register store**
1. `createUserWithEmailAndPassword(username@<storeId>.pocketpos.app, password)` — a **synthesized,
   store-scoped** email so the same username can exist across stores. (25s network timeout.)
2. **Reserve email** in a transaction on `email_index/{email.lowercase}` → enforces
   one-email-one-store; on conflict it throws and **rolls back** the just-created auth user.
3. Write `stores/{storeId}` (`status: pending`), `stores/{storeId}/users/{uid}` (role `owner`),
   and `user_store_index/{uid}`.
4. Seed the chosen business type's demo catalog via `StoreCatalogSeeder` (one atomic
   `WriteBatch` for categories + products + opening inventory + default warehouse).

**Login (store)** — Store ID + username + password → sign in with the synthesized email →
load `StoreSession` (with cache fallback so it works when transport stalls).

**Platform admin** — a real email/password Firebase user whose `uid` also has a
`platform_admins/{uid}` doc. `adminLogin` signs in, checks the doc, and routes to the approval
screen. The **first admin is bootstrapped in the console** (see `docs/platforadmin.md`).

**Routing/redirects** (`lib/app/router.dart`): stage machine — `loggedOut` → store login;
`pending` → pending-approval screen; `active` → dashboard/shell; `admin` → approvals. A session
bridge maps the store role → in-app role (owner/manager/cashier) and POS counter.

---

## 5. Security rules

`firestore.rules` (deploy with `firebase deploy --only firestore:rules`):

- `stores/{storeId}` — `create` by a signed-in user for their own pending store; `get` by a
  store member or platform admin; `update` (status) only by platform admins; a
  `match /{document=**}` grants members read/write to all tenant subcollections.
- `user_store_index/{uid}` — owner-only read/write.
- `platform_admins/{uid}` — self `get`; only admins `list`/`write`.
- `email_index/{email}` — `get` for any signed-in user (availability check; no `list` → limits
  enumeration); `create` only when absent and `uid == request.auth.uid`; `update` forbidden;
  `delete` only by the reserving owner (rollback).

Rules are validated with the Firestore **emulator** (`@firebase/rules-unit-testing`) but must be
**deployed** to take effect in the app.

---

## 6. Feature notes

- **Products** — auto product code, opening stock, per-product tax. Barcode via camera
  (`mobile_scanner`) or HID keyboard-wedge; **EAN-13 generation** for barcode-less items; a saved
  barcode auto-fills the form. **OCR name from photo** via ML Kit is isolated behind a conditional
  import (`product_name_scanner.dart` → `_mobile.dart` on `dart.library.io`, `_stub.dart`
  elsewhere) so the web build never references ML Kit.
- **Inventory** — modes No/Single/Multiple; per-warehouse rows; transfers; low-stock; a
  "sync products" backfill creating missing stock rows.
- **Sales / POS** — multi-cart, POS counters, offline checkout (atomic sale+items+payment+cart
  batch, then stock decrement). Invoice **PDF** printing reads sale items/products from Firestore.
- **Staff** — Firestore-backed registration, attendance, monthly payroll and salary payments.

---

## 7. Web & marketing

`web/index.html` boots Flutter behind a full-screen **SEO landing overlay**; `enterApp()` reveals
the app, `/?app=1` deep-links in. Static blog (`web/blog/`) + `web/contact.html` carry JSON-LD
(Organization/SoftwareApplication/BlogPosting/Breadcrumb/FAQ/ContactPage), `robots.txt` and
`sitemap.xml`. Deployed to GitHub Pages via `.github/workflows/deploy_web.yml` (custom domain
`mypocketpos.in`); `firebase.json` also carries a Hosting config.

---

## 8. Known caveats / gotchas
- **Deploy rules after changing them** — mismatched deployed rules vs. code (e.g. `email_index`)
  break registration with `permission-denied`.
- **Android identity** is `com.mypocketpos.app`; keep `google-services.json` + SHA fingerprints in
  sync with the Firebase project, or device sign-in stalls (Play Integrity / reCAPTCHA).
- **Project id** should match across `.firebaserc` and `lib/firebase_options.dart`.
- Any **client-side third-party HTTP** (e.g. calling an email API directly from the app) is
  blocked by CORS on web and would leak secrets in the bundle — do such work server-side.
- Ids must stay **< 2^53**; `firestore_ids.dart` guarantees this — don't change it to microseconds.
