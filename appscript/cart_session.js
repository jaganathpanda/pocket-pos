/**
 * Pocket POS – Public Customer Cart Session
 * ==========================================
 * Deployed as a Google Apps Script Web App (Execute as: Me, Access: Anyone).
 *
 * POST /exec
 * Body (JSON):
 *   { "storeId": "STR-XXXXXX", "customerName": "Ravi", "mobile": "9876543210" }
 *
 * Success response 200:
 *   { "customToken": "<firebase-custom-token>", "cartId": 12345678, "storeName": "..." }
 *
 * Error response 400/403:
 *   { "error": "Human-readable message" }
 *
 * Setup (one-time):
 *   1. Open Apps Script project → Project Settings → Script Properties.
 *   2. Add the following properties:
 *        FIREBASE_PROJECT_ID   → pocket-pos-35e48
 *        SERVICE_ACCOUNT_EMAIL → <service-account>@pocket-pos-35e48.iam.gserviceaccount.com
 *        SERVICE_ACCOUNT_KEY   → <PEM private key, include header/footer, replace newlines with \n>
 *   3. Deploy as Web App. Copy the /exec URL into Flutter's
 *      lib/core/constants/app_constants.dart (CART_SESSION_ENDPOINT).
 */

// ─── Configuration ────────────────────────────────────────────────────────────

var PROPS = PropertiesService.getScriptProperties();
var PROJECT_ID   = PROPS.getProperty('FIREBASE_PROJECT_ID');
var SA_EMAIL     = PROPS.getProperty('SERVICE_ACCOUNT_EMAIL');
var SA_KEY       = PROPS.getProperty('SERVICE_ACCOUNT_KEY');

// Firestore base URL (v1 REST)
var FS_BASE = 'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID + '/databases/(default)/documents';

// Custom token lifetime in seconds (30 minutes)
var TOKEN_TTL_S = 30 * 60;

// Rate-limit: max attempts per mobile per minute
var RATE_LIMIT   = 5;
var RATE_WINDOW  = 60; // seconds

// ─── Entry point ──────────────────────────────────────────────────────────────

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents || '{}');
    var storeId      = (body.storeId      || '').toString().trim().toUpperCase();
    var customerName = (body.customerName || '').toString().trim();
    var mobile       = (body.mobile       || '').toString().trim();

    // 1. Input validation
    if (!storeId || !customerName || !mobile) {
      return _err(400, 'storeId, customerName and mobile are required.');
    }
    if (!/^STR-[A-Z0-9]{6}$/.test(storeId)) {
      return _err(400, 'Invalid store ID format.');
    }
    if (!/^\+?[0-9]{7,15}$/.test(mobile.replace(/[\s\-()]/g, ''))) {
      return _err(400, 'Invalid mobile number.');
    }
    if (customerName.length > 80) {
      return _err(400, 'Customer name too long (max 80 characters).');
    }

    // 2. Rate limit by mobile number (CacheService, per-minute window)
    var cacheKey = 'rl_' + mobile;
    var cache    = CacheService.getScriptCache();
    var attempts = parseInt(cache.get(cacheKey) || '0', 10);
    if (attempts >= RATE_LIMIT) {
      return _err(429, 'Too many requests. Please wait a minute and try again.');
    }
    cache.put(cacheKey, String(attempts + 1), RATE_WINDOW);

    // 3. Platform global feature flag
    var platformDoc = _fsGet('platform_config/public_features');
    if (!platformDoc || platformDoc.fields.allowAnonymousShopping.booleanValue !== true) {
      return _err(403, 'Public storefront shopping is disabled by platform.');
    }

    // 4. Store existence + approval
    var storeDoc = _fsGet('stores/' + storeId);
    if (!storeDoc) {
      return _err(404, 'Store ID not found.');
    }
    var storeStatus = _str(storeDoc.fields.status);
    if (storeStatus !== 'approved') {
      return _err(403, 'This store is not accepting customer carts yet.');
    }
    var storeName = _str(storeDoc.fields.name) || storeId;

    // 5. Store-level storefront setting + schedule window
    var sfDoc = _fsGet('stores/' + storeId + '/settings/storefront');
    if (!sfDoc || sfDoc.fields.allowAnonymousShopping.booleanValue !== true) {
      return _err(403, 'This store has disabled customer storefront shopping.');
    }

    if (sfDoc.fields.autoWindowEnabled && sfDoc.fields.autoWindowEnabled.booleanValue === true) {
      var startTs = _tsToDate(sfDoc.fields.windowStartAt);
      var endTs   = _tsToDate(sfDoc.fields.windowEndAt);
      if (!startTs || !endTs || endTs <= startTs) {
        return _err(403, 'This store has an invalid shopping schedule. Contact store owner.');
      }
      var now = new Date();
      if (now < startTs) {
        return _err(403, 'Public shopping is not open yet for this store.');
      }
      if (now > endTs) {
        return _err(403, 'Public shopping is currently closed for this store.');
      }
    }

    // 6. Allocate a cartId (same algorithm as Dart newIntId)
    var cartId = (Date.now() * 1000 + Math.floor(Math.random() * 1000));

    // 7. Mint Firebase Custom Token with scoped claims
    var claims = {
      role:    'customer_cart',
      storeId: storeId,
      cartId:  cartId
    };
    var customToken = _mintCustomToken(String(cartId), claims);

    // 8. Return token + cartId + storeName to Flutter
    return ContentService
      .createTextOutput(JSON.stringify({
        customToken: customToken,
        cartId:      cartId,
        storeName:   storeName
      }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    Logger.log('cart_session error: ' + err);
    return _err(500, 'Internal error. Please try again.');
  }
}

// ─── Firebase Custom Token (JWT) ──────────────────────────────────────────────

function _mintCustomToken(uid, claims) {
  var now   = Math.floor(Date.now() / 1000);
  var header  = { alg: 'RS256', typ: 'JWT' };
  var payload = {
    iss: SA_EMAIL,
    sub: SA_EMAIL,
    aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    iat: now,
    exp: now + TOKEN_TTL_S,
    uid: uid,
    claims: claims
  };

  var b64h = Utilities.base64EncodeWebSafe(JSON.stringify(header)).replace(/=+$/, '');
  var b64p = Utilities.base64EncodeWebSafe(JSON.stringify(payload)).replace(/=+$/, '');
  var toSign = b64h + '.' + b64p;

  // RSA-SHA256 sign using the service account private key
  var keyBytes  = Utilities.newBlob(SA_KEY).getBytes();
  var signature = Utilities.computeRsaSha256Signature(toSign, SA_KEY);
  var b64s      = Utilities.base64EncodeWebSafe(signature).replace(/=+$/, '');

  return toSign + '.' + b64s;
}

// ─── Firestore REST helpers ───────────────────────────────────────────────────

function _fsGet(path) {
  var token = ScriptApp.getOAuthToken();
  var resp  = UrlFetchApp.fetch(FS_BASE + '/' + path, {
    method:             'GET',
    headers:            { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true
  });
  if (resp.getResponseCode() === 404) return null;
  if (resp.getResponseCode() !== 200)  throw new Error('Firestore GET failed: ' + resp.getContentText());
  var doc = JSON.parse(resp.getContentText());
  return doc.fields ? doc : null; // return null when document has no fields
}

function _str(field) {
  if (!field) return '';
  return field.stringValue || '';
}

function _tsToDate(field) {
  if (!field || !field.timestampValue) return null;
  return new Date(field.timestampValue);
}

// ─── Response helpers ─────────────────────────────────────────────────────────

function _err(code, message) {
  return ContentService
    .createTextOutput(JSON.stringify({ error: message, code: code }))
    .setMimeType(ContentService.MimeType.JSON);
}
