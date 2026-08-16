/**
 * Pocket POS – Main Server Handler (cart_session.js)
 * =================================================
 * Customer cart session creation endpoint.
 *
 * Customer cart creation is allowed ONLY when:
 *
 *   1. Platform admin has enabled:
 *        allowAnonymousShopping == true
 *
 *   AND
 *
 *   2. Store owner has enabled:
 *        stores/{storeId}/settings/storefront
 *        allowAnonymousShopping == true
 *
 * The server checks both flags BEFORE creating the cart
 * or minting the customer Firebase custom token.
 */

// ─── CONFIGURATION & SCRIPT PROPERTIES ────────────────────────────────────────

var scriptProps = PropertiesService.getScriptProperties();

var SA_KEY = scriptProps.getProperty('SERVICE_ACCOUNT_KEY');
var SA_EMAIL = scriptProps.getProperty('SERVICE_ACCOUNT_EMAIL');
var PROJECT_ID = scriptProps.getProperty('FIREBASE_PROJECT_ID');

/*
 * Platform feature flag location.
 *
 * IMPORTANT:
 * The attached Flutter files confirm the field name:
 *
 *   allowAnonymousShopping
 *
 * The exact platform-config document path is owned by
 * storeAuthService.setStorefrontFeatureFlag().
 *
 * If your existing platform config is stored somewhere else,
 * change ONLY these constants.
 */
var PLATFORM_CONFIG_COLLECTION = 'platform_config';
var PLATFORM_CONFIG_DOCUMENT = 'public_features';


/* ─── MAIN DOPOST HANDLER ───────────────────────────────────────────────────── */

function doPost(e) {
  try {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Validate request
    // ─────────────────────────────────────────────────────────────────────────

    if (!e || !e.postData || !e.postData.contents) {
      return _jsonResponse({
        error: 'Invalid or empty request payload.',
        code: 400
      });
    }

    var requestData;

    try {
      requestData = JSON.parse(e.postData.contents);
    } catch (parseError) {
      return _jsonResponse({
        error: 'Malformed JSON payload.',
        code: 400
      });
    }

    var storeId = requestData.storeId;

    var customerName =
      requestData.customerName != null &&
      String(requestData.customerName).trim() !== ''
        ? String(requestData.customerName).trim()
        : 'Guest';

    var mobile =
      requestData.mobile != null
        ? String(requestData.mobile).trim()
        : '';

    if (!storeId) {
      return _jsonResponse({
        error: 'Missing required parameter: storeId',
        code: 400
      });
    }

    storeId = String(storeId).trim();

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Get service-account OAuth token
    // ─────────────────────────────────────────────────────────────────────────

    var accessToken = _getServiceAccountAccessToken();

    // ─────────────────────────────────────────────────────────────────────────
    // 3. CHECK BOTH FEATURE FLAGS
    // ─────────────────────────────────────────────────────────────────────────
    //
    // Platform flag:
    //
    //   platform_config/{document}
    //       allowAnonymousShopping == true
    //
    // Store flag:
    //
    //   stores/{storeId}/settings/storefront
    //       allowAnonymousShopping == true
    //
    // The cart is NOT created if either flag is false.
    // ─────────────────────────────────────────────────────────────────────────

    var featureStatus =
      _checkStoreFeatureStatus(storeId, accessToken);

    if (!featureStatus.allowed) {
      return _jsonResponse({
        success: false,
        error: featureStatus.reason,
        code: 403
      });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Generate numeric Cart ID
    // ─────────────────────────────────────────────────────────────────────────

   var cartId = Number(String(Date.now()) +String(Math.floor(Math.random() * 1000)));

    var storeName =
      featureStatus.storeName || 'Pocket POS Store';

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Create Firestore cart
    // ─────────────────────────────────────────────────────────────────────────

    _createCartDocument(
      PROJECT_ID,
      cartId,
      storeId,
      customerName,
      mobile,
      accessToken
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Mint Firebase Custom Token
    // ─────────────────────────────────────────────────────────────────────────
    //
    // IMPORTANT:
    // Claims are placed DIRECTLY into the JWT payload.
    //
    // DO NOT use:
    //
    //   claims: claims
    //
    // because Firebase expects custom claims to be top-level claims.
    // ─────────────────────────────────────────────────────────────────────────

    var customToken = _mintCustomToken(String(cartId), {
      storeId: storeId,
      cartId: cartId,
      role: 'customer_cart'
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Return session information
    // ─────────────────────────────────────────────────────────────────────────

    return _jsonResponse({
      success: true,
      cartId: cartId,
      storeName: storeName,
      customToken: customToken
    });

  } catch (err) {

    Logger.log(
      'cart_session error: ' +
      (err && err.stack ? err.stack : err)
    );

    return _jsonResponse({
      success: false,
      error: 'Internal error: ' + (err.message || err),
      code: 500
    });
  }
}


/* ─── PRIVATE KEY SANITIZER ─────────────────────────────────────────────────── */

function _getFormattedPrivateKey() {

  if (!SA_KEY) {
    throw new Error(
      "Script property 'SERVICE_ACCOUNT_KEY' is missing or empty."
    );
  }

  var unescapedKey = SA_KEY
    .replace(/^["']|["']$/g, '')
    .replace(/\\\\n/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\r/g, '');

  var header = '-----BEGIN PRIVATE KEY-----';
  var footer = '-----END PRIVATE KEY-----';

  var startIndex = unescapedKey.indexOf(header);
  var endIndex = unescapedKey.indexOf(footer);

  if (startIndex === -1 || endIndex === -1) {
    throw new Error(
      'Key structure invalid. Missing BEGIN or END headers.'
    );
  }

  var base64Content = unescapedKey
    .substring(
      startIndex + header.length,
      endIndex
    )
    .replace(/\s+/g, '');

  var lines = [];

  for (var i = 0; i < base64Content.length; i += 64) {
    lines.push(
      base64Content.substring(i, i + 64)
    );
  }

  return (
    header +
    '\n' +
    lines.join('\n') +
    '\n' +
    footer
  );
}


/* ─── AUTHENTICATION HELPERS ─────────────────────────────────────────────────── */

function _getServiceAccountAccessToken() {

  var cleanKey = _getFormattedPrivateKey();

  var now = Math.floor(Date.now() / 1000);

  var header = {
    alg: 'RS256',
    typ: 'JWT'
  };

  var payload = {
    iss: SA_EMAIL,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  };

  var b64Header =
    Utilities.base64EncodeWebSafe(
      JSON.stringify(header)
    ).replace(/=+$/, '');

  var b64Payload =
    Utilities.base64EncodeWebSafe(
      JSON.stringify(payload)
    ).replace(/=+$/, '');

  var toSign =
    b64Header + '.' + b64Payload;

  var signature =
    Utilities.computeRsaSha256Signature(
      toSign,
      cleanKey
    );

  var b64Sign =
    Utilities.base64EncodeWebSafe(signature)
      .replace(/=+$/, '');

  var jwt =
    toSign + '.' + b64Sign;

  var response = UrlFetchApp.fetch(
    'https://oauth2.googleapis.com/token',
    {
      method: 'post',
      contentType:
        'application/x-www-form-urlencoded',
      payload: {
        grant_type:
          'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      },
      muteHttpExceptions: true
    }
  );

  if (response.getResponseCode() !== 200) {
    throw new Error(
      'Failed to fetch OAuth token: ' +
      response.getContentText()
    );
  }

  var resJson =
    JSON.parse(response.getContentText());

  return resJson.access_token;
}


/**
 * Mint Firebase custom token.
 *
 * IMPORTANT:
 * Custom claims are merged directly into the JWT payload.
 */
function _mintCustomToken(uid, claims) {
  var cleanKey = _getFormattedPrivateKey();
  var now = Math.floor(Date.now() / 1000);

  var header = {
    alg: 'RS256',
    typ: 'JWT'
  };

  var payload = {
  iss: SA_EMAIL,
  sub: SA_EMAIL,
  aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
  iat: now,
  exp: now + 3600,
  uid: String(uid),

  claims: {
    storeId: String(claims.storeId),
    cartId: String(claims.cartId),
    role: String(claims.role)
  }
};

  // IMPORTANT:
  // Firebase custom claims must be TOP-LEVEL JWT claims.
  Object.keys(claims || {}).forEach(function(key) {
    payload[key] = claims[key];
  });

  Logger.log('========== CUSTOM TOKEN PAYLOAD ==========');
  Logger.log(JSON.stringify(payload, null, 2));
  Logger.log('==========================================');

  var b64Header =
    Utilities.base64EncodeWebSafe(
      JSON.stringify(header)
    ).replace(/=+$/, '');

  var b64Payload =
    Utilities.base64EncodeWebSafe(
      JSON.stringify(payload)
    ).replace(/=+$/, '');

  var toSign =
    b64Header + '.' + b64Payload;

  var signature =
    Utilities.computeRsaSha256Signature(
      toSign,
      cleanKey
    );

  var b64Sign =
    Utilities.base64EncodeWebSafe(signature)
      .replace(/=+$/, '');

  return toSign + '.' + b64Sign;
}

/**  ─── FIRESTORE OPERATIONS ───────────────────────────────────────────────────── */


/**
 * Checks:
 *
 * 1. Store exists
 * 2. Platform customer-shopping flag is enabled
 * 3. Store-owner customer-shopping flag is enabled
 *
 * Both flags must be TRUE.
 */
function _checkStoreFeatureStatus(storeId, accessToken) {

  // ─────────────────────────────────────────────────────────────────────────
  // A. Check store document
  // ─────────────────────────────────────────────────────────────────────────

  var storeUrl =
    'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID +
    '/databases/(default)/documents/stores/' +
    encodeURIComponent(storeId);

  var storeResponse = UrlFetchApp.fetch(
    storeUrl,
    {
      method: 'get',
      headers: {
        Authorization:
          'Bearer ' + accessToken
      },
      muteHttpExceptions: true
    }
  );

  if (storeResponse.getResponseCode() === 404) {
    return {
      allowed: false,
      reason: 'Store ID does not exist.'
    };
  }

  if (storeResponse.getResponseCode() !== 200) {
    Logger.log(
      'Store lookup failed: ' +
      storeResponse.getContentText()
    );

    return {
      allowed: false,
      reason: 'Unable to verify store status.'
    };
  }

  var storeData =
    JSON.parse(storeResponse.getContentText());

  var storeFields =
    storeData.fields || {};

  var storeName =
    storeFields.name &&
    storeFields.name.stringValue
      ? storeFields.name.stringValue
      : 'Store ' + storeId;


  // ─────────────────────────────────────────────────────────────────────────
  // B. Check PLATFORM feature flag
  // ─────────────────────────────────────────────────────────────────────────

  var platformConfig =
    _getFirestoreDocument(
      PLATFORM_CONFIG_COLLECTION,
      PLATFORM_CONFIG_DOCUMENT,
      accessToken
    );

  if (!platformConfig.exists) {

    Logger.log(
      'Platform storefront feature document does not exist: ' +
      PLATFORM_CONFIG_COLLECTION +
      '/' +
      PLATFORM_CONFIG_DOCUMENT
    );

    return {
      allowed: false,
      reason:
        'Customer shopping is not enabled by the platform administrator.'
    };
  }

  var platformFields =
    platformConfig.fields || {};

  var platformEnabled =
    _getBooleanField(
      platformFields,
      'allowAnonymousShopping',
      false
    );

  if (!platformEnabled) {

    return {
      allowed: false,
      reason:
        'Customer shopping is currently disabled by the platform administrator.'
    };
  }


  // ─────────────────────────────────────────────────────────────────────────
  // C. Check STORE OWNER feature flag
  // ─────────────────────────────────────────────────────────────────────────

  var storefrontConfig =
    _getFirestoreSubcollectionDocument(
      'stores',
      storeId,
      'settings',
      'storefront',
      accessToken
    );

  if (!storefrontConfig.exists) {

    return {
      allowed: false,
      reason:
        'Customer shopping has not been enabled for this store.'
    };
  }

  var storefrontFields =
    storefrontConfig.fields || {};

  var storeEnabled =
    _getBooleanField(
      storefrontFields,
      'allowAnonymousShopping',
      false
    );

  if (!storeEnabled) {

    return {
      allowed: false,
      reason:
        'Customer shopping is disabled for this store.'
    };
  }


  // ─────────────────────────────────────────────────────────────────────────
  // D. Both flags enabled
  // ─────────────────────────────────────────────────────────────────────────

  return {
    allowed: true,
    storeName: storeName
  };
}


/**
 * Get a top-level Firestore document.
 *
 * collectionName/documentId
 */
function _getFirestoreDocument(
  collectionName,
  documentId,
  accessToken
) {

  var url =
    'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID +
    '/databases/(default)/documents/' +
    encodeURIComponent(collectionName) +
    '/' +
    encodeURIComponent(documentId);

  var response = UrlFetchApp.fetch(
    url,
    {
      method: 'get',
      headers: {
        Authorization:
          'Bearer ' + accessToken
      },
      muteHttpExceptions: true
    }
  );

  if (response.getResponseCode() === 404) {
    return {
      exists: false,
      fields: {}
    };
  }

  if (response.getResponseCode() !== 200) {

    throw new Error(
      'Firestore document lookup failed: ' +
      response.getContentText()
    );
  }

  var data =
    JSON.parse(response.getContentText());

  return {
    exists: true,
    fields: data.fields || {}
  };
}


/**
 * Get:
 *
 * stores/{storeId}/settings/{documentId}
 */
function _getFirestoreSubcollectionDocument(
  rootCollection,
  rootDocumentId,
  subcollection,
  documentId,
  accessToken
) {

  var url =
    'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID +
    '/databases/(default)/documents/' +
    encodeURIComponent(rootCollection) +
    '/' +
    encodeURIComponent(rootDocumentId) +
    '/' +
    encodeURIComponent(subcollection) +
    '/' +
    encodeURIComponent(documentId);

  var response = UrlFetchApp.fetch(
    url,
    {
      method: 'get',
      headers: {
        Authorization:
          'Bearer ' + accessToken
      },
      muteHttpExceptions: true
    }
  );

  if (response.getResponseCode() === 404) {

    return {
      exists: false,
      fields: {}
    };
  }

  if (response.getResponseCode() !== 200) {

    throw new Error(
      'Firestore subcollection lookup failed: ' +
      response.getContentText()
    );
  }

  var data =
    JSON.parse(response.getContentText());

  return {
    exists: true,
    fields: data.fields || {}
  };
}


/**
 * Reads a Firestore boolean field.
 *
 * Returns defaultValue when:
 * - field does not exist
 * - field is not a boolean
 */
function _getBooleanField(
  fields,
  fieldName,
  defaultValue
) {

  if (
    !fields ||
    !fields[fieldName]
  ) {
    return defaultValue;
  }

  var field =
    fields[fieldName];

  if (
    field.booleanValue !== undefined
  ) {
    return field.booleanValue === true;
  }

  return defaultValue;
}


/**
 * Creates a new active customer cart.
 */
function _createCartDocument(
  projectId,
  cartId,
  storeId,
  customerName,
  mobile,
  accessToken
) {

  var url =
    'https://firestore.googleapis.com/v1/projects/' +
    projectId +
    '/databases/(default)/documents/stores/' +
    encodeURIComponent(storeId) +
    '/carts?documentId=' +
    encodeURIComponent(String(cartId));

  var now =
    new Date().toISOString();

  var payload = {
    fields: {

      storeId: {
        stringValue: String(storeId)
      },

      customerName: {
        stringValue: String(customerName || 'Guest')
      },

      customerMobile: {
        stringValue: String(mobile || '')
      },

      name: {
        stringValue: String(customerName || 'Guest')
      },

      source: {
        stringValue: 'customer'
      },

      status: {
        stringValue: 'active'
      },

      posCounterId: {
        nullValue: 'NULL_VALUE'
      },

      customerId: {
        nullValue: 'NULL_VALUE'
      },

      warehouseId: {
        nullValue: 'NULL_VALUE'
      },

      createdAt: {
        timestampValue: now
      },

      updatedAt: {
        timestampValue: now
      }
    }
  };

  var response = UrlFetchApp.fetch(
    url,
    {
      method: 'post',
      contentType: 'application/json',
      headers: {
        Authorization:
          'Bearer ' + accessToken
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    }
  );

  if (response.getResponseCode() !== 200) {

    throw new Error(
      'Failed to create cart document: ' +
      response.getContentText()
    );
  }

  return true;
}


/* ─── UTILITY FUNCTIONS ─────────────────────────────────────────────────────── */

function _jsonResponse(data) {

  return ContentService
    .createTextOutput(
      JSON.stringify(data)
    )
    .setMimeType(
      ContentService.MimeType.JSON
    );
}


/* ─── DEBUGGING & TEST SUITE ────────────────────────────────────────────────── */

/**
 * Main Debugger Function.
 */
function runDoPostDebugger() {

  Logger.log(
    '================================================='
  );

  Logger.log(
    '🚀 STARTING POST HANDLER DEBUG SUITE'
  );

  Logger.log(
    '=================================================\n'
  );


  // TEST 1: Valid Storefront Request
  _testSimulateDoPost(
    '1. VALID REQUEST',
    {
      storeId: 'STR-BPWCP3',
      customerName: 'Debug User',
      mobile: '9876543210'
    }
  );


  // TEST 2: Missing Store ID
  _testSimulateDoPost(
    '2. MISSING STORE ID',
    {
      customerName: 'Invalid User',
      mobile: '9876543210'
    }
  );


  // TEST 3: Invalid Store ID
  _testSimulateDoPost(
    '3. NON-EXISTENT STORE',
    {
      storeId: 'STR-INVALID-9999',
      customerName: 'Ghost Customer',
      mobile: '0000000000'
    }
  );


  Logger.log(
    '\n================================================='
  );

  Logger.log(
    '🏁 DEBUG SUITE COMPLETE'
  );

  Logger.log(
    '================================================='
  );
}


/**
 * Helper to mock doPost().
 */
function _testSimulateDoPost(
  testName,
  payloadObject
) {

  Logger.log(
    '--- Testing: ' +
    testName +
    ' ---'
  );

  var mockEvent = {
    postData: {
      contents:
        JSON.stringify(payloadObject)
    }
  };

  try {

    var startTime = Date.now();

    var responseOutput =
      doPost(mockEvent);

    var duration =
      Date.now() - startTime;

    var content =
      responseOutput.getContent();

    var mimeType =
      responseOutput.getMimeType();

    Logger.log(
      '⏱️ Execution Time: ' +
      duration +
      ' ms'
    );

    Logger.log(
      '📄 Response MIME: ' +
      mimeType
    );

    Logger.log(
      '📦 Response Payload:\n' +
      content
    );

    var parsed =
      JSON.parse(content);

    if (parsed.success) {

      Logger.log(
        '✅ PASSED: Custom token & cart generated successfully!'
      );

      Logger.log(
        '   -> Store Name: ' +
        parsed.storeName
      );

      Logger.log(
        '   -> Cart ID: ' +
        parsed.cartId
      );

      Logger.log(
        '   -> Custom Token Length: ' +
        (
          parsed.customToken
            ? parsed.customToken.length
            : 0
        )
      );

    } else {

      Logger.log(
        '⚠️ HANDLED ERROR: ' +
        parsed.error
      );
    }

  } catch (err) {

    Logger.log(
      '❌ CRITICAL SCRIPT EXCEPTION: ' +
      err.toString()
    );

    if (err.stack) {

      Logger.log(
        '   Stack Trace:\n' +
        err.stack
      );
    }
  }

  Logger.log('\n');
}