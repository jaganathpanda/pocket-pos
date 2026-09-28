/**
 * Main Webhook Dispatcher (Code.gs)
 */

// Handle CORS preflight requests from web clients
function doOptions(e) {
  return HtmlService.createHtmlOutput('')
    .addHeader('Access-Control-Allow-Origin', '*')
    .addHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    .addHeader('Access-Control-Allow-Headers', 'Content-Type')
    .setHttpResponseCode(204);
}

function doPost(e) {
  try {
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

    // Route 1: Store Registration Webhook (Handled in store_registration.gs)
    if (requestData.storeData && requestData.storeId) {
      return handleStoreRegistration(requestData.storeId, requestData.storeData);
    }

    // Route 2: Cart Session Webhook (Handled in cart_session.js)
    return doPostCartSession(requestData);

  } catch (err) {
    Logger.log('Router Error: ' + (err && err.stack ? err.stack : err));
    return _jsonResponse({
      success: false,
      error: 'Internal error: ' + (err.message || err),
      code: 500
    });
  }
}

function runDoPostRegistrationTest() {
  Logger.log('=================================================');
  Logger.log('🚀 TESTING DOPOST ROUTER FOR REGISTRATION');
  Logger.log('=================================================\n');

  var mockEvent = {
    postData: {
      contents: JSON.stringify({
        storeId: 'STR-ROUTER99',
        storeData: {
          name: 'Router Test Store',
          ownerName: 'Router Tester',
          ownerUsername: 'routeruser',
          email: 'jaga1706@gmail.com', // ⚠️ CHANGE THIS to your test email
          businessType: 'RETAIL'
        }
      })
    }
  };

  try {
    var response = doPost(mockEvent);
    Logger.log('📦 doPost Response Payload:\n' + response.getContent());
  } catch (err) {
    Logger.log('❌ doPost Test Error: ' + err.toString());
  }
}

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

function doPostCartSession(e) {
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
    )
    .addHeader('Access-Control-Allow-Origin', '*')
    .addHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    .addHeader('Access-Control-Allow-Headers', 'Content-Type');
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

/**
 * Pocket POS – Store Registration Handler (store_registration.gs)
 */

function handleStoreRegistration(storeId, storeData) {
  var accessToken = _getServiceAccountAccessToken();

  // 1. Generate activation token
  var token = _generateSecureToken(32);

  // 2. Persist the activation token into Firestore
  _saveActivationTokenToFirestore(storeId, token, accessToken);

  // 3. Construct activation link
  var BASE_ACTIVATION_URL = 'https://mypocketpos.in/#/activate';
  var activationUrl = BASE_ACTIVATION_URL + 
    '?storeId=' + encodeURIComponent(storeId) + 
    '&token=' + encodeURIComponent(token);

  var ownerName = storeData.ownerName || 'Store Owner';
  var storeName = storeData.name || storeId;
  var targetEmail = storeData.email;

  if (!targetEmail) {
    return _jsonResponse({
      success: false,
      error: 'Missing store owner email.',
      code: 400
    });
  }

  // 4. Generate HTML content
  var htmlBody = generateWelcomeEmailHTML({
    ownerName: ownerName,
    storeName: storeName,
    storeId: storeId,
    activationUrl: activationUrl
  });

  // 5. Send Email via Resend
  try {
    var subject = 'Activate Your Pocket POS Store - ' + storeName;
    var resendResult = sendEmailWithResend(targetEmail, subject, htmlBody, accessToken);

    if (!resendResult.sent) {
      return _jsonResponse({
        success: false,
        error: resendResult.reason,
        code: 403
      });
    }

    return _jsonResponse({
      success: true,
      message: 'Activation email sent successfully via Resend.',
      storeId: storeId,
      emailId: resendResult.id
    });

  } catch (err) {
    Logger.log('Email dispatch error: ' + err.message);
    return _jsonResponse({
      success: false,
      error: 'Failed to send activation email: ' + err.message,
      code: 500
    });
  }
}


/* ─── FIRESTORE TOKEN PATCH ──────────────────────────────────────────────────── */

function _saveActivationTokenToFirestore(storeId, tokenToSave, accessToken) {
  if (!tokenToSave) {
    throw new Error('Cannot update Firestore: token is undefined or empty.');
  }

  var url = 'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID +
    '/databases/(default)/documents/stores/' +
    encodeURIComponent(storeId) +
    '?updateMask.fieldPaths=activationToken';

  var payload = {
    fields: {
      activationToken: {
        stringValue: String(tokenToSave)
      }
    }
  };

  var response = UrlFetchApp.fetch(url, {
    method: 'patch',
    contentType: 'application/json',
    headers: {
      Authorization: 'Bearer ' + accessToken
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });

  if (response.getResponseCode() !== 200) {
    throw new Error('Failed to update store activation token: ' + response.getContentText());
  }

  return true;
}


/* ─── SECURE TOKEN HELPER ───────────────────────────────────────────────────── */

function _generateSecureToken(length) {
  var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  var result = '';
  for (var i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
/* ─── EMAIL TEMPLATES ────────────────────────────────────────────────────────── */

function generateWelcomeEmailHTML(params) {
  var ownerName = params.ownerName || 'Valued Customer';
  var storeName = params.storeName || 'Your Store';
  var storeId = params.storeId || '';
  var activationUrl = params.activationUrl || 'https://mypocketpos.in/';
  var websiteUrl = params.websiteUrl || 'https://mypocketpos.in/';
  var supportEmail = params.supportEmail || 'support@mypocketpos.in';

  return '<!DOCTYPE html>\n' +
    '<html lang="en">\n' +
    '<head>\n' +
    '    <meta charset="UTF-8">\n' +
    '    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n' +
    '    <title>Welcome to Pocket POS</title>\n' +
    '    <style>\n' +
    '        body { margin: 0; padding: 0; background-color: #f4faf7; font-family: Arial, Helvetica, sans-serif; color: #10212b; }\n' +
    '        table { border-spacing: 0; }\n' +
    '        a { text-decoration: none; }\n' +
    '        .email-container { width: 100%; max-width: 700px; margin: 0 auto; }\n' +
    '        .mobile-padding { padding-left: 45px; padding-right: 45px; }\n' +
    '        .hero-title { font-size: 42px; line-height: 1.1; font-weight: 800; margin: 0; color: #10212b; }\n' +
    '        .hero-green { color: #079455; }\n' +
    '        .feature-title { font-size: 16px; font-weight: bold; color: #10212b; }\n' +
    '        .feature-text { font-size: 13px; line-height: 1.4; color: #536872; }\n' +
    '        @media screen and (max-width: 600px) {\n' +
    '            .email-container { width: 100% !important; }\n' +
    '            .mobile-padding { padding-left: 22px !important; padding-right: 22px !important; }\n' +
    '            .hero-title { font-size: 32px !important; }\n' +
    '            .feature-column { display: block !important; width: 100% !important; padding-bottom: 25px !important; }\n' +
    '            .footer-column { display: block !important; width: 100% !important; text-align: center !important; padding-bottom: 20px !important; }\n' +
    '        }\n' +
    '    </style>\n' +
    '</head>\n' +
    '<body>\n' +
    '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f4faf7;">\n' +
    '    <tr>\n' +
    '        <td align="center">\n' +
    '            <table class="email-container" width="700" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff;">\n' +
    '                \n' +
    '                <!-- HEADER -->\n' +
    '                <tr>\n' +
    '                    <td class="mobile-padding" style="padding-top:35px;padding-bottom:20px;">\n' +
    '                        <table width="100%" cellpadding="0" cellspacing="0">\n' +
    '                            <tr>\n' +
    '                                <td align="left">\n' +
    '                                    <table cellpadding="0" cellspacing="0">\n' +
    '                                        <tr>\n' +
    '                                            <td>\n' +
    '                                                <div style="width:52px;height:52px;background:#079455;border-radius:12px;color:#ffffff;font-size:30px;font-weight:bold;text-align:center;line-height:52px;">P</div>\n' +
    '                                            </td>\n' +
    '                                            <td style="padding-left:12px;">\n' +
    '                                                <a href="' + websiteUrl + '" style="text-decoration:none;">\n' +
    '                                                    <div style="font-size:30px;line-height:30px;font-weight:800;color:#10212b;">Pocket <span style="color:#079455;">POS</span></div>\n' +
    '                                                    <div style="font-size:12px;color:#536872;margin-top:5px;">Simple Billing • Smarter Business</div>\n' +
    '                                                </a>\n' +
    '                                            </td>\n' +
    '                                        </tr>\n' +
    '                                    </table>\n' +
    '                                </td>\n' +
    '                                <td align="right" style="color:#079455;font-size:18px;font-weight:bold;line-height:1.2;font-style:italic;">Grow Your Store<br>Every Day</td>\n' +
    '                            </tr>\n' +
    '                        </table>\n' +
    '                    </td>\n' +
    '                </tr>\n' +
    '\n' +
    '                <!-- HERO TITLE -->\n' +
    '                <tr>\n' +
    '                    <td class="mobile-padding" style="padding-top:15px;padding-bottom:25px;">\n' +
    '                        <div style="width:65px;height:5px;background:#079455;margin-bottom:20px;"></div>\n' +
    '                        <h1 class="hero-title">Welcome to <span class="hero-green">Pocket POS!</span></h1>\n' +
    '                        <p style="font-size:17px;line-height:1.5;color:#263944;margin-top:15px;">Thank you for registering with <strong>Pocket POS</strong>. We are thrilled to partner with you!</p>\n' +
    '                    </td>\n' +
    '                </tr>\n' +
    '\n' +
    '                <!-- MAIN BODY CARD -->\n' +
    '                <tr>\n' +
    '                    <td class="mobile-padding">\n' +
    '                        <table width="100%" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:18px;box-shadow:0 8px 35px rgba(0,0,0,0.08);border:1px solid #edf3ef;">\n' +
    '                            <tr>\n' +
    '                                <td style="padding:35px;">\n' +
    '                                    <div style="font-size:23px;font-weight:bold;color:#10212b;">Hi ' + ownerName + ',</div>\n' +
    '                                    <div style="font-size:18px;line-height:1.5;margin-top:12px;color:#263944;">Welcome to <strong style="color:#079455;">Pocket POS</strong> for <strong>' + storeName + '</strong>.</div>\n' +
    '                                    \n' +
    '                                    <!-- STORE ID BOX -->\n' +
    '                                    <table cellpadding="0" cellspacing="0" style="margin-top:20px;">\n' +
    '                                        <tr>\n' +
    '                                            <td style="font-size:17px;color:#263944;padding-right:12px;">Your Store ID:</td>\n' +
    '                                            <td style="background:#e7f8f0;border-radius:10px;padding:12px 22px;font-size:20px;font-weight:bold;color:#067c49;">' + storeId + '</td>\n' +
    '                                        </tr>\n' +
    '                                    </table>\n' +
    '\n' +
    '                                    <!-- ACTIVATION INSTRUCTION BOX -->\n' +
    '                                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:25px;background:#f0fdf4;border-radius:14px;border:1px solid #bbf7d0;">\n' +
    '                                        <tr>\n' +
    '                                            <td width="55" align="center" valign="middle" style="padding:18px 0 18px 18px;">\n' +
    '                                                <div style="width:40px;height:40px;background:#079455;border-radius:50%;font-size:20px;line-height:40px;color:#ffffff;text-align:center;">✓</div>\n' +
    '                                            </td>\n' +
    '                                            <td style="padding:15px 20px 15px 12px;">\n' +
    '                                                <div style="color:#15803d;font-size:17px;font-weight:bold;">Activate Your Store Account</div>\n' +
    '                                                <div style="color:#263944;font-size:15px;line-height:1.5;margin-top:4px;">Click the button below to complete registration and activate your account.</div>\n' +
    '                                            </td>\n' +
    '                                        </tr>\n' +
    '                                    </table>\n' +
    '\n' +
    '                                    <!-- PRIMARY ACTION BUTTON -->\n' +
    '                                    <table cellpadding="0" cellspacing="0" style="margin-top:25px;">\n' +
    '                                        <tr>\n' +
    '                                            <td style="background:#079455;border-radius:30px;">\n' +
    '                                                <a href="' + activationUrl + '" style="display:inline-block;padding:16px 36px;color:#ffffff;font-size:18px;font-weight:bold;text-decoration:none;">Activate Store Account <span style="font-size:20px;padding-left:10px;">→</span></a>\n' +
    '                                            </td>\n' +
    '                                        </tr>\n' +
    '                                    </table>\n' +
    '\n' +
    '                                    <!-- ALTERNATIVE DIRECT LINK -->\n' +
    '                                    <p style="color:#60777f;font-size:13px;line-height:1.5;margin-top:20px;word-break:break-all;">\n' +
    '                                        Or copy & paste this link into your browser:<br>\n' +
    '                                        <a href="' + activationUrl + '" style="color:#079455;text-decoration:underline;">' + activationUrl + '</a>\n' +
    '                                    </p>\n' +
    '\n' +
    '                                    <!-- SUPPORT NOTE -->\n' +
    '                                    <p style="color:#60777f;font-size:15px;line-height:1.5;margin-top:25px;">If you have any questions or need help setting up, please reach out to our team at <a href="mailto:' + supportEmail + '" style="color:#079455;font-weight:bold;">' + supportEmail + '</a>.</p>\n' +
    '\n' +
    '                                    <!-- SIGNATURE -->\n' +
    '                                    <div style="margin-top:28px;font-size:15px;line-height:1.5;color:#263944;">\n' +
    '                                        Regards,<br>\n' +
    '                                        <strong style="font-size:17px;">Pocket POS Team</strong><br>\n' +
    '                                        <a href="' + websiteUrl + '" style="color:#079455;font-weight:bold;text-decoration:none;">https://mypocketpos.in/</a>\n' +
    '                                    </div>\n' +
    '                                </td>\n' +
    '                            </tr>\n' +
    '                        </table>\n' +
    '                    </td>\n' +
    '                </tr>\n' +
    '\n' +
    '                <!-- FEATURES LIST -->\n' +
    '                <tr>\n' +
    '                    <td class="mobile-padding" style="padding-top:35px;padding-bottom:35px;">\n' +
    '                        <table width="100%" cellpadding="0" cellspacing="0">\n' +
    '                            <tr>\n' +
    '                                <td class="feature-column" width="25%" valign="top" style="padding-right:15px;">\n' +
    '                                    <div style="width:50px;height:50px;background:#d8f8e9;border-radius:50%;text-align:center;line-height:50px;font-size:25px;color:#079455;">⚡</div>\n' +
    '                                    <div class="feature-title" style="margin-top:12px;">Fast Billing</div>\n' +
    '                                    <div class="feature-text" style="margin-top:5px;">Complete bills in seconds</div>\n' +
    '                                </td>\n' +
    '                                <td class="feature-column" width="25%" valign="top" style="padding-right:15px;">\n' +
    '                                    <div style="width:50px;height:50px;background:#d8f8e9;border-radius:50%;text-align:center;line-height:50px;font-size:23px;color:#079455;">☁</div>\n' +
    '                                    <div class="feature-title" style="margin-top:12px;">Works Offline</div>\n' +
    '                                    <div class="feature-text" style="margin-top:5px;">Keep selling, anytime</div>\n' +
    '                                </td>\n' +
    '                                <td class="feature-column" width="25%" valign="top" style="padding-right:15px;">\n' +
    '                                    <div style="width:50px;height:50px;background:#d8f8e9;border-radius:50%;text-align:center;line-height:50px;font-size:23px;color:#079455;">✓</div>\n' +
    '                                    <div class="feature-title" style="margin-top:12px;">GST Compliant</div>\n' +
    '                                    <div class="feature-text" style="margin-top:5px;">Generate GST-ready invoices</div>\n' +
    '                                </td>\n' +
    '                                <td class="feature-column" width="25%" valign="top">\n' +
    '                                    <div style="width:50px;height:50px;background:#d8f8e9;border-radius:50%;text-align:center;line-height:50px;font-size:23px;color:#079455;">↗</div>\n' +
    '                                    <div class="feature-title" style="margin-top:12px;">Grow Your Business</div>\n' +
    '                                    <div class="feature-text" style="margin-top:5px;">Powerful tools for better insights</div>\n' +
    '                                </td>\n' +
    '                            </tr>\n' +
    '                        </table>\n' +
    '                    </td>\n' +
    '                </tr>\n' +
    '\n' +
    '                <!-- FOOTER -->\n' +
    '                <tr>\n' +
    '                    <td style="background:#004f42;padding:35px 45px;color:#ffffff;">\n' +
    '                        <table width="100%" cellpadding="0" cellspacing="0">\n' +
    '                            <tr>\n' +
    '                                <td class="footer-column" width="50%" valign="top">\n' +
    '                                    <div style="font-size:25px;font-weight:bold;">🛍 Pocket <span style="color:#8de6bb;">POS</span></div>\n' +
    '                                    <div style="font-size:12px;margin-top:6px;color:#c8e9dc;">Simple Billing • Smarter Business</div>\n' +
    '                                </td>\n' +
    '                                <td class="footer-column" width="50%" align="right" valign="top">\n' +
    '                                    <div style="font-size:15px;font-weight:bold;">Need Help?</div>\n' +
    '                                    <div style="margin-top:8px;font-size:13px;line-height:1.6;color:#d8eee7;">\n' +
    '                                        <a href="mailto:' + supportEmail + '" style="color:#ffffff;text-decoration:underline;">' + supportEmail + '</a><br>\n' +
    '                                        <a href="' + websiteUrl + '" style="color:#ffffff;text-decoration:underline;">https://mypocketpos.in/</a>\n' +
    '                                    </div>\n' +
    '                                </td>\n' +
    '                            </tr>\n' +
    '                        </table>\n' +
    '                    </td>\n' +
    '                </tr>\n' +
    '            </table>\n' +
    '        </td>\n' +
    '    </tr>\n' +
    '</table>\n' +
    '</body>\n' +
    '</html>';
}


/* ─── TEST SUITE ────────────────────────────────────────────────────────────── */

function testRegistrationEmail() {
  Logger.log("=== RUNNING TEST: testRegistrationEmail ===");
  var mockEvent = {
    postData: {
      contents: JSON.stringify({
        storeId: "STR-TEST99",
        storeData: {
          name: "Test Retail Store",
          ownerName: "John Doe",
          ownerUsername: "johndoe",
          email: "test@example.com",
          businessType: "retail",
          mobile: "+919876543210"
        }
      })
    }
  };

  try {
    var data = JSON.parse(mockEvent.postData.contents);
    var response = handleStoreRegistration(data.storeId, data.storeData);
    Logger.log("✅ Test result:\n" + JSON.stringify(response, null, 2));
  } catch (err) {
    Logger.log("❌ Test error: " + (err.message || err.toString()));
  }
  Logger.log("=== TEST COMPLETED ===");
}
/**
 * Pocket POS – Resend Email Integration (resend_service.gs)
 * Reads email settings from Firestore: platform_config/notifications
 */

/**
 * Fetches notification settings from Firestore and dispatches the email via Resend if enabled.
 *
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject line
 * @param {string} html - Email HTML body content
 * @param {string} accessToken - Service account OAuth access token
 */
function sendEmailWithResend(to, subject, html, accessToken) {
  // 1. Fetch notification config from Firestore: platform_config/notifications
  var config = _getNotificationConfig(accessToken);

  if (!config.enabled) {
    Logger.log('⚠️ Email notification is disabled in platform_config/notifications.');
    return {
      sent: false,
      reason: 'Email notifications disabled in platform configuration.'
    };
  }

  if (!config.apiKey) {
    throw new Error('Resend API Key is missing in platform_config/notifications.');
  }

  var fromAddress = config.fromAddress || 'info@mypocketpos.in';

  // 2. Format sender name if address doesn't already contain one
  var senderHeader = fromAddress.indexOf('<') !== -1 
    ? fromAddress 
    : 'Pocket POS <' + fromAddress + '>';

  var payload = {
    from: senderHeader,
    to: [to],
    subject: subject,
    html: html
  };

  // 3. Post to Resend API
  var response = UrlFetchApp.fetch('https://api.resend.com/emails', {
    method: 'post',
    contentType: 'application/json',
    headers: {
      Authorization: 'Bearer ' + config.apiKey
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });

  var statusCode = response.getResponseCode();
  var responseText = response.getContentText();

  if (statusCode !== 200 && statusCode !== 201) {
    throw new Error('Resend API HTTP ' + statusCode + ': ' + responseText);
  }

  var resData = JSON.parse(responseText);
  Logger.log('✅ Email sent via Resend successfully! Email ID: ' + resData.id);

  return {
    sent: true,
    id: resData.id
  };
}


/**
 * Private helper: Reads platform_config/notifications from Firestore
 */
function _getNotificationConfig(accessToken) {
  var url = 'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID +
    '/databases/(default)/documents/platform_config/notifications';

  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    headers: {
      Authorization: 'Bearer ' + accessToken
    },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() !== 200) {
    throw new Error('Failed to read platform_config/notifications: ' + response.getContentText());
  }

  var docData = JSON.parse(response.getContentText());
  var fields = docData.fields || {};

  // Extract nested 'email' map from document
  var emailMap = (fields.email && fields.email.mapValue && fields.email.mapValue.fields) 
    ? fields.email.mapValue.fields 
    : {};

  var apiKey = emailMap.apiKey && emailMap.apiKey.stringValue 
    ? emailMap.apiKey.stringValue 
    : '';

  var fromAddress = emailMap.fromAddress && emailMap.fromAddress.stringValue 
    ? emailMap.fromAddress.stringValue 
    : 'info@mypocketpos.in';

  var enabled = emailMap.enabled && emailMap.enabled.booleanValue !== undefined 
    ? emailMap.enabled.booleanValue === true 
    : false;

  return {
    apiKey: apiKey,
    fromAddress: fromAddress,
    enabled: enabled
  };
}