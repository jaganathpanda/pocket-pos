/**
 * Pocket POS – Referral Reward Processor (Apps Script)
 * ====================================================
 *
 * This worker runs on a time-based Apps Script trigger and processes
 * store-level pending referral rewards.
 *
 * It mirrors the backend behavior that previously ran in Firebase Functions:
 * - checks stores with referralRewardStatus == 'pending'
 * - reads platform referral settings
 * - verifies referred store has a qualifying sale (minCartAmount)
 * - resolves source referrer by referralCode from collection-group users
 * - credits referralRewards on source user
 * - marks referred store as credited/skipped/invalid
 */

var REFERRAL_TRIGGER_FUNCTION = 'processPendingReferralRewards';

function installReferralRewardsTrigger() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === REFERRAL_TRIGGER_FUNCTION) {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }

  ScriptApp.newTrigger(REFERRAL_TRIGGER_FUNCTION)
    .timeBased()
    .everyMinutes(5)
    .create();
}

function processPendingReferralRewards() {
  var settingsDoc = _fsGetDoc_('platform_config/referral_settings');
  var settings = settingsDoc ? _decodeFields_(settingsDoc.fields || {}) : {};

  var enabled = settings.enabled !== false;
  var minCartAmount = _toNumber_(settings.minCartAmount, 0);

  var pendingReferrals = _queryPendingReferralDocs_();
  if (!pendingReferrals.length) return;

  for (var i = 0; i < pendingReferrals.length; i++) {
    _processSinglePendingReferral_(pendingReferrals[i], {
      enabled: enabled,
      minCartAmount: minCartAmount,
    });
  }
}

function _queryPendingReferralDocs_() {
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'referrals', allDescendants: true }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'pending' },
        },
      },
      limit: 100,
    },
  };

  var rows = _fsRunQuery_(payload);
  var docs = [];
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] && rows[i].document) docs.push(rows[i].document);
  }
  return docs;
}

function _processSinglePendingReferral_(referralDoc, settings) {
  var referralData = _decodeFields_(referralDoc.fields || {});
  var referralId = (referralDoc.name || '').split('/').pop();
  var referredStoreId = _normalizeReferralCode_(referralData.referredStoreId);
  var referrerStoreId = _normalizeReferralCode_(referralData.referrerStoreId);
  var referrerUid = typeof referralData.referrerUid === 'string'
    ? referralData.referrerUid.trim()
    : '';
  var referredUid = typeof referralData.referredUid === 'string'
    ? referralData.referredUid.trim()
    : '';
  var referralCode = _normalizeReferralCode_(referralData.referralCode);
  var rewardAmount = _toNumber_(referralData.rewardAmount, 0);

  if (!referralId || !referredStoreId || !referrerStoreId || !referrerUid || !referredUid || rewardAmount <= 0) {
    return;
  }

  if (!settings.enabled) {
    _patchReferralDoc_(referralDoc.name, {
      status: 'skipped_disabled',
      evaluatedAt: _serverTimestamp_(),
    });
    return;
  }

  var qualifyingSale = _findFirstQualifyingSale_(referredStoreId, settings.minCartAmount);
  if (!qualifyingSale) {
    return;
  }

  _commitReferralCredit_(
    referralDoc.name,
    referredStoreId,
    qualifyingSale.saleId,
    referralCode,
    referrerStoreId,
    referrerUid,
    referredUid,
    rewardAmount
  );
}

function _queryStoresByRewardStatus_(status) {
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'stores' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'referralRewardStatus' },
          op: 'EQUAL',
          value: { stringValue: status },
        },
      },
      limit: 50,
    },
  };

  var rows = _fsRunQuery_(payload);
  var docs = [];
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] && rows[i].document) docs.push(rows[i].document);
  }
  return docs;
}

function _findFirstQualifyingSale_(storeId, minCartAmount) {
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'sales' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'grandTotal' },
          op: 'GREATER_THAN_OR_EQUAL',
          value: { doubleValue: minCartAmount },
        },
      },
      orderBy: [{ field: { fieldPath: 'soldAt' }, direction: 'ASCENDING' }],
      limit: 1,
    },
  };

  var rows = _fsRunQuery_(payload, 'stores/' + storeId);
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i] || !rows[i].document) continue;
    var doc = rows[i].document;
    var saleId = doc.name.split('/').pop();
    if (saleId) return { saleId: saleId, doc: doc };
  }
  return null;
}

function _findReferrerByCode_(referralCode) {
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'users', allDescendants: true }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'referralCode' },
          op: 'EQUAL',
          value: { stringValue: referralCode },
        },
      },
      limit: 1,
    },
  };

  var rows = _fsRunQuery_(payload);
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i] || !rows[i].document) continue;
    var doc = rows[i].document;
    var parts = doc.name.split('/');
    var storeIdx = parts.indexOf('stores');
    var usersIdx = parts.indexOf('users');
    if (storeIdx < 0 || usersIdx < 0 || usersIdx + 1 >= parts.length) continue;

    return {
      storeId: parts[storeIdx + 1],
      uid: parts[usersIdx + 1],
      userDocName: doc.name,
    };
  }

  return null;
}

function _commitReferralCredit_(referralDocName, referredStoreId, saleId, referralCode, referrerStoreId, referrerUid, referredUid, rewardAmount) {
  var baseDocPath = 'projects/' + PROJECT_ID + '/databases/(default)/documents';
  var now = _serverTimestamp_();

  var storeDocPath = 'stores/' + referredStoreId;
  var referrerUserPath = 'stores/' + referrerStoreId + '/users/' + referrerUid;
  var eventPath = 'stores/' + referredStoreId + '/referral_reward_events/' + String(saleId);
  var referralDocPath = referralDocName.replace('projects/' + PROJECT_ID + '/databases/(default)/documents/', '');

  var writes = [
    {
      update: {
        name: baseDocPath + '/' + referrerUserPath,
        fields: {
          lastReferralRewardAt: now,
        },
      },
      updateMask: {
        fieldPaths: ['lastReferralRewardAt'],
      },
      currentDocument: {
        exists: true,
      },
      updateTransforms: [
        {
          fieldPath: 'referralRewards',
          increment: { doubleValue: rewardAmount },
        },
      ],
    },
    {
      update: {
        name: baseDocPath + '/' + storeDocPath,
        fields: _encodeFields_({
          referralRewardStatus: 'credited',
          referralRewardAmount: rewardAmount,
          referralRewardedAt: now,
          referralSourceStoreId: referrerStoreId,
          referralSourceUid: referrerUid,
          referralRewardSaleId: String(saleId),
          referralRewardEvaluatedAt: now,
        }),
      },
      updateMask: {
        fieldPaths: [
          'referralRewardStatus',
          'referralRewardAmount',
          'referralRewardedAt',
          'referralSourceStoreId',
          'referralSourceUid',
          'referralRewardSaleId',
          'referralRewardEvaluatedAt',
        ],
      },
      currentDocument: {
        exists: true,
      },
    },
    {
      update: {
        name: baseDocPath + '/' + eventPath,
        fields: _encodeFields_({
          saleId: String(saleId),
          referralCode: referralCode,
          sourceStoreId: referrerStoreId,
          sourceUid: referrerUid,
          referredUid: referredUid,
          rewardAmount: rewardAmount,
          createdAt: now,
        }),
      },
      updateMask: {
        fieldPaths: [
          'saleId',
          'referralCode',
          'sourceStoreId',
          'sourceUid',
          'rewardAmount',
          'createdAt',
        ],
      },
    },
    {
      update: {
        name: baseDocPath + '/' + referralDocPath,
        fields: _encodeFields_({
          status: 'rewarded',
          completedAt: now,
          rewardedAt: now,
          rewardedSaleId: String(saleId),
        }),
      },
      updateMask: {
        fieldPaths: [
          'status',
          'completedAt',
          'rewardedAt',
          'rewardedSaleId',
        ],
      },
      currentDocument: {
        exists: true,
      },
    },
  ];

  _fsCommit_({ writes: writes });
}

function _patchReferralDoc_(docName, map) {
  var path = docName.replace('projects/' + PROJECT_ID + '/databases/(default)/documents/', '');
  _fsPatchDoc_(path, map);
}

function _patchStoreRewardStatus_(storeId, map) {
  _fsPatchDoc_('stores/' + storeId, map);
}

function _normalizeReferralCode_(value) {
  if (typeof value !== 'string') return '';
  return value.trim().toUpperCase();
}

function _toNumber_(value, fallback) {
  if (typeof value === 'number' && isFinite(value)) return value;
  return fallback;
}

function _serverTimestamp_() {
  return { timestampValue: new Date().toISOString() };
}

function _fsGetDoc_(path) {
  var token = ScriptApp.getOAuthToken();
  var resp = UrlFetchApp.fetch(FS_BASE + '/' + path, {
    method: 'GET',
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true,
  });
  if (resp.getResponseCode() === 404) return null;
  if (resp.getResponseCode() !== 200) {
    throw new Error('Firestore GET failed: ' + resp.getContentText());
  }
  return JSON.parse(resp.getContentText());
}

function _fsPatchDoc_(path, map) {
  var token = ScriptApp.getOAuthToken();
  var fieldPaths = Object.keys(map);
  var query = '';
  for (var i = 0; i < fieldPaths.length; i++) {
    query += (i === 0 ? '?' : '&') + 'updateMask.fieldPaths=' + encodeURIComponent(fieldPaths[i]);
  }

  var resp = UrlFetchApp.fetch(FS_BASE + '/' + path + query, {
    method: 'PATCH',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify({ fields: _encodeFields_(map) }),
    muteHttpExceptions: true,
  });

  if (resp.getResponseCode() !== 200) {
    throw new Error('Firestore PATCH failed: ' + resp.getContentText());
  }
}

function _fsRunQuery_(structuredPayload, parentPath) {
  var token = ScriptApp.getOAuthToken();
  var parent = parentPath
    ? 'projects/' + PROJECT_ID + '/databases/(default)/documents/' + parentPath
    : 'projects/' + PROJECT_ID + '/databases/(default)/documents';

  var url = 'https://firestore.googleapis.com/v1/' + parent + ':runQuery';
  var resp = UrlFetchApp.fetch(url, {
    method: 'POST',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify(structuredPayload),
    muteHttpExceptions: true,
  });

  if (resp.getResponseCode() !== 200) {
    throw new Error('Firestore runQuery failed: ' + resp.getContentText());
  }

  var rows = JSON.parse(resp.getContentText());
  return Array.isArray(rows) ? rows : [];
}

function _fsCommit_(payload) {
  var token = ScriptApp.getOAuthToken();
  var url = 'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID + '/databases/(default)/documents:commit';
  var resp = UrlFetchApp.fetch(url, {
    method: 'POST',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
  if (resp.getResponseCode() !== 200) {
    throw new Error('Firestore commit failed: ' + resp.getContentText());
  }
}

function _encodeFields_(map) {
  var out = {};
  var keys = Object.keys(map);
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    out[key] = _encodeValue_(map[key]);
  }
  return out;
}

function _encodeValue_(value) {
  if (value === null || value === undefined) return { nullValue: null };

  if (typeof value === 'object') {
    if (value.timestampValue) {
      return { timestampValue: value.timestampValue };
    }
    if (Array.isArray(value)) {
      var arr = [];
      for (var i = 0; i < value.length; i++) arr.push(_encodeValue_(value[i]));
      return { arrayValue: { values: arr } };
    }
    return { mapValue: { fields: _encodeFields_(value) } };
  }

  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Math.floor(value) === value) return { integerValue: String(value) };
    return { doubleValue: value };
  }

  return { stringValue: String(value) };
}

function _decodeFields_(fields) {
  var out = {};
  var keys = Object.keys(fields || {});
  for (var i = 0; i < keys.length; i++) {
    out[keys[i]] = _decodeValue_(fields[keys[i]]);
  }
  return out;
}

function _decodeValue_(node) {
  if (!node || typeof node !== 'object') return null;
  if (Object.prototype.hasOwnProperty.call(node, 'stringValue')) return node.stringValue;
  if (Object.prototype.hasOwnProperty.call(node, 'booleanValue')) return node.booleanValue;
  if (Object.prototype.hasOwnProperty.call(node, 'integerValue')) return Number(node.integerValue);
  if (Object.prototype.hasOwnProperty.call(node, 'doubleValue')) return Number(node.doubleValue);
  if (Object.prototype.hasOwnProperty.call(node, 'timestampValue')) return node.timestampValue;
  if (Object.prototype.hasOwnProperty.call(node, 'nullValue')) return null;

  if (node.mapValue && node.mapValue.fields) {
    return _decodeFields_(node.mapValue.fields);
  }
  if (node.arrayValue && Array.isArray(node.arrayValue.values)) {
    var arr = [];
    for (var i = 0; i < node.arrayValue.values.length; i++) {
      arr.push(_decodeValue_(node.arrayValue.values[i]));
    }
    return arr;
  }

  return null;
}