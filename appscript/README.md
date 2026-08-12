# Pocket POS – Apps Script Cart Session

## Purpose

This Google Apps Script Web App acts as a lightweight trusted backend for
anonymous customer cart creation.  
It replaces Firebase anonymous auth and complex Firestore rules with a single
secure endpoint that:

1. Validates inputs and rate-limits by mobile number.
2. Checks the platform global feature flag.
3. Verifies store approval + store-level storefront setting.
4. Enforces the optional auto-schedule window (start/stop time).
5. Mints a scoped **Firebase Custom Token** (30 min TTL) with claims:
   `{ role: "customer_cart", storeId, cartId }`.
6. Returns `{ customToken, cartId, storeName }` to the Flutter client.

Flutter then calls `FirebaseAuth.signInWithCustomToken(customToken)` and
writes the cart directly to Firestore. Firestore rules verify only the token
claims — no `get()` lookups needed in rules.

---

## Files

| File | Purpose |
|---|---|
| `cart_session.js` | Web App entry point (`doPost`) + JWT minting + Firestore REST helpers |
| `appsscript.json` | Apps Script project manifest |

---

## One-time Setup

1. Go to [script.google.com](https://script.google.com) → New project.
2. Paste the contents of `cart_session.js` into `Code.gs`.
3. Replace the manifest in `appsscript.json` with the contents of `appsscript.json`.
4. Open **Project Settings → Script Properties** and add:

   | Property | Value |
   |---|---|
   | `FIREBASE_PROJECT_ID` | `pocket-pos-35e48` |
   | `SERVICE_ACCOUNT_EMAIL` | `<sa>@pocket-pos-35e48.iam.gserviceaccount.com` |
   | `SERVICE_ACCOUNT_KEY` | Full PEM private key (replace literal `\n` with newlines) |

5. **Deploy → New deployment → Web App**
   - Execute as: **Me**
   - Who has access: **Anyone** (anonymous, no Google sign-in required)
6. Copy the `/exec` URL.
7. Paste it into `lib/core/constants/app_constants.dart`:
   ```dart
   static const cartSessionEndpoint = 'https://script.google.com/macros/s/.../exec';
   ```

---

## Service Account Setup

1. Firebase Console → Project Settings → Service Accounts → Generate new private key.
2. Download the JSON. Copy `client_email` → `SERVICE_ACCOUNT_EMAIL`.
3. Copy `private_key` → `SERVICE_ACCOUNT_KEY`.
4. In IAM & Admin give the service account the **Firebase Authentication Admin** role.

---

## Flutter Integration

See `lib/features/store/presentation/public_storefront_page.dart`.  
The `_startShopping()` method now:
1. POSTs to the Apps Script endpoint.
2. Receives `{ customToken, cartId, storeName }`.
3. Signs into Firebase with the custom token.
4. Writes the cart document using the pre-allocated `cartId`.

---

## Firestore Rules Impact

Rules no longer need:
- `isPublicStorefrontUser`
- `isPublicStorefrontAllowedNow`
- `get()` calls for schedule/platform flags

They use only:
```
function isCustomerCartToken(storeId, cartId) {
  return request.auth.token.role == 'customer_cart'
    && request.auth.token.storeId == storeId
    && request.auth.token.cartId == cartId;
}
```
