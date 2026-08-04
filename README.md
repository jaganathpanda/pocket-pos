# Pocket POS

A multi-tenant, **offline-first** point-of-sale & billing platform for retail (kirana / grocery,
pharmacy, bakery, electronics, apparel). Built with **Flutter** and **Firebase (Cloud
Firestore + Auth)**, it runs on **Web** (`https://mypocketpos.in`) and **Android** from a single
codebase.

Each store is an isolated tenant. Owners self-register, get approved by a platform admin, then
run billing, inventory, purchases, customers, credit (udhar), staff and reports — all working
without internet and syncing to the cloud when back online.

---

## Table of contents
- [Features](#features)
- [Tech stack](#tech-stack)
- [Architecture at a glance](#architecture-at-a-glance)
- [Multi-tenancy & auth model](#multi-tenancy--auth-model)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Firebase setup](#firebase-setup)
- [Web, SEO & hosting](#web-seo--hosting)
- [More docs](#more-docs)

---

## Features

**Billing / POS**
- Multi-cart billing (create, hold/resume, rename, transfer a cart between counters)
- **POS counters** (POS1, POS2…): owner creates counter logins; counter users only see their own carts/sales
- Cash / credit (udhar) / partial payments; GST-ready invoices with automatic tax totals
- Fully **offline** — carts, add-item and checkout all work with no connection and sync later

**Products & catalog**
- Product CRUD with auto-generated product code, opening stock, per-product tax
- **Barcode**: scan via phone camera (`mobile_scanner`) or USB/Bluetooth **HID** scanners; generate a valid in-store **EAN-13** for items with no barcode
- **Read product name from a photo** via on-device **ML Kit OCR** (Android/iOS only; auto-hidden on web)
- Category management; business-type demo catalogs seeded at registration

**Inventory & warehouses**
- Three inventory modes: **No inventory / Single warehouse / Multiple warehouses**
- Per-warehouse stock, stock transfers, low-stock thresholds
- "Sync products" backfill to create stock rows for any product missing one
- Stock auto-decrements on sale, auto-increments on purchase

**Parties, money & people**
- Customers (with credit/udhar ledger), suppliers/vendors, purchases
- Expenses, sales reports with **CSV export** and **PDF invoice printing**
- Staff registration, attendance and payroll

**Platform**
- Store self-registration with **one-email-one-store** uniqueness enforcement
- Platform-admin approval workflow (approve / suspend stores)
- SEO marketing site (landing + blog + contact) served alongside the app

---

## Tech stack

| Layer | Choice |
|---|---|
| UI / app | Flutter (Material 3), `flutter_riverpod` (state + DI), `go_router` (routing) |
| Cloud data | **Cloud Firestore** (multi-tenant, offline persistence enabled) |
| Auth | **Firebase Auth** (email/password; store logins use a synthesized email) |
| Local models / legacy | **Drift (SQLite)** — its generated model classes are reused as Firestore DTOs |
| Barcode | `mobile_scanner` (camera) + a keyboard-style HID listener |
| OCR | `google_mlkit_text_recognition` + `image_picker` (mobile only, isolated via conditional import) |
| PDF / print | `printing` |
| Marketing site | Static HTML/CSS in `web/` (landing, `web/blog/`, `web/contact.html`) |

---

## Architecture at a glance

Layering per feature: `presentation/` (widgets + Riverpod controllers) → `domain/` (repository
interfaces + models) → `data/` (Firestore implementations).

- **Repository pattern.** Every feature defines an abstract repository in `domain/`; the live
  implementation is a Firestore class in `data/` (e.g. `FirestoreProductRepository`). All
  providers are wired in `lib/core/di/providers.dart`, scoped to the active tenant.
- **DTO reuse.** Firestore repos return the existing **Drift model classes** (`Product`,
  `Cart`, `Sale`, …) so the UI didn't change during the Firestore migration. Documents use an
  **integer id as the document id** (kept below 2^53 so it's exact on web — see
  `core/firestore/firestore_ids.dart`).
- **Offline-first patterns** (detail in `docs/ARCHITECTURE.md`):
  - Firestore **offline persistence** is enabled in `main.dart`.
  - **Writes are fire-and-forget** in the billing path (`queueWrite` in `store_scope.dart` /
    `_write` in the sales repo). A Firestore write applies to the local cache instantly but its
    Future only resolves on *server* ack, so awaiting it would hang the UI offline — we never
    await the terminal write.
  - **Reads use `cacheSafeDoc`** — a plain `doc().get()` throws `unavailable` offline for an
    uncached doc, so we fall back to a documentId **query** (queries serve from cache offline).
  - The **app shell keeps warehouse + inventory listeners alive** so those caches stay warm for
    the offline add-to-cart / checkout path.

---

## Multi-tenancy & auth model

All tenant data lives under `stores/{storeId}/…`. `lib/core/firestore/store_scope.dart`
(`storeCollection`) is the single place isolation is applied; `activeStoreIdProvider` supplies
the current tenant.

- **Store registration** (`features/store/data/store_auth_service.dart`): creates a Firebase Auth
  user with a **synthesized email** `username@<storeId>.pocketpos.app` (so the same username can
  exist in different stores), atomically **reserves the real email** in `email_index/{email}` to
  enforce one-email-one-store (with rollback on conflict), writes the `stores/{storeId}` doc
  (status `pending`), and seeds the chosen business type's demo catalog.
- **Store login**: Store ID + username + password.
- **Approval**: a store is `pending` until a **platform admin** approves it (see
  `docs/platforadmin.md` for how to bootstrap the first admin).
- **Roles**: owner / manager / cashier; POS-counter users are scoped to their counter.

Firestore security rules (`firestore.rules`) enforce: store-member access under
`stores/{storeId}`, `user_store_index` (uid→store), `platform_admins`, and the `email_index`
uniqueness reservation. **Rules must be deployed** (`firebase deploy --only firestore:rules`) —
the emulator only tests them locally.

---

## Project structure

```
lib/
  app/                 # app widget + go_router (routes, redirects, shell nav)
  core/
    database/          # Drift schema + generated code + demo seed data
    di/providers.dart  # all Riverpod providers (Firestore repos, scoped by store)
    firestore/         # store_scope, firestore_ids, mappers, cacheSafeDoc, seeder
    services/          # e.g. receipt PDF service
    utilities/ widgets/ constants/
  features/
    store/             # registration, login, admin approval (multi-tenant auth)
    auth/              # in-app session (role, counter) bridged from store session
    products/ categories/ inventory/ warehouse/
    sales/ multicart/ pos_counters/
    customers/ suppliers/ purchases/ ledger/ expense/
    reports/ staff/ dashboard/ settings/ barcode/ variants/
web/                   # Flutter web bootstrap + marketing site (landing, blog/, contact.html)
docs/                  # architecture, deployment, install, platform-admin, ER diagram
```

---

## Getting started

Prerequisites: Flutter (stable), Android toolchain, and the Firebase CLI + FlutterFire CLI.

```bash
flutter pub get
# Drift codegen (needed after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run -d chrome     # web
flutter run -d <device>   # Android
```

There are **no seeded/hard-coded logins** — create a store via the Register screen (it seeds a
demo catalog for the chosen business type), then approve it as a platform admin.

---

## Firebase setup

1. **Configure** the app for your Firebase project (generates `lib/firebase_options.dart` and
   `android/app/google-services.json`):
   ```bash
   flutterfire configure
   ```
2. **Enable Email/Password** in Firebase Console → Authentication → Sign-in method.
3. **Authorized domains**: add `mypocketpos.in` (and any staging subdomain) under Auth settings.
4. **Deploy security rules & indexes**:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
5. **Android identity**: applicationId is `com.mypocketpos.app` (minSdk 23 for Firebase Auth).
   Add the app's **SHA-1 and SHA-256** fingerprints (debug + release) in the console, or
   device sign-in can stall on Play Integrity / reCAPTCHA.
6. **Platform admin**: see [`docs/platforadmin.md`](docs/platforadmin.md).

> Keep the project id consistent between `.firebaserc` and `lib/firebase_options.dart`.

---

## Web, SEO & hosting

- **App**: Flutter web boots behind a full-screen marketing overlay in `web/index.html`;
  the Login/Register buttons reveal the app (`enterApp()`), and `/?app=1` deep-links straight in.
- **Marketing site**: SEO landing (`web/index.html`), blog (`web/blog/…`) and
  `web/contact.html`, with JSON-LD (Organization, SoftwareApplication, BlogPosting,
  BreadcrumbList, FAQ, ContactPage), `robots.txt` and `sitemap.xml`.
- **Deploy (GitHub Pages)**: `.github/workflows/deploy_web.yml` builds on push to `main`,
  writes the `CNAME`, and publishes `build/web` to the `gh-pages` branch (custom domain
  `mypocketpos.in`). A Firebase Hosting config also exists in `firebase.json`.

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the full deploy runbook and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the technical deep-dive.

---

## More docs
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — layers, data model, offline-first internals
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — build & release for web/Android + Firebase
- [`docs/INSTALLATION_GUIDE.md`](docs/INSTALLATION_GUIDE.md) — local setup
- [`docs/platforadmin.md`](docs/platforadmin.md) — creating/logging in a platform admin
- [`docs/FOLDER_STRUCTURE.md`](docs/FOLDER_STRUCTURE.md) · [`docs/PHASE_ROADMAP.md`](docs/PHASE_ROADMAP.md)
