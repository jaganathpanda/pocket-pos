# Firebase Functions Deployment Guide

This document explains how to deploy the Pocket POS Firebase Function used for server-side notifications (Email/SMS/WhatsApp), including required secrets, rules deployment, verification, and safe testing.

## Prerequisites

1. Install Node.js 20+.
2. Install Firebase CLI:

```bash
npm install -g firebase-tools
```

3. Ensure you have access to the target Firebase project.

## 1) Login and Select Project

From the project root:

```bash
firebase login
firebase use --add
```

Select the Pocket POS Firebase project and set it as default for this workspace.

## 2) Install Function Dependencies

```bash
cd functions
npm install
cd ..
```

## 3) Enable Required Google APIs (First Deploy)

Run a deploy once and approve prompts to enable required APIs:

```bash
firebase deploy --only functions
```

Typical APIs required:

1. Cloud Functions API
2. Cloud Build API
3. Artifact Registry API
4. Secret Manager API
5. Eventarc API

## 4) Configure Secrets

Set required secrets used by the current implementation:

```bash
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
```

## 5) Deploy Firestore Rules

Notification feature flag config uses platform-level Firestore documents, so deploy rules first:

```bash
firebase deploy --only firestore:rules
```

## 6) Deploy Functions

```bash
firebase deploy --only functions
```

## 7) Verify Deployment

1. List functions:

```bash
firebase functions:list
```

2. Confirm function is active in Firebase Console:

- Function name: `sendWelcomeEmailOnStoreRegistration`

3. Check logs:

```bash
firebase functions:log --only sendWelcomeEmailOnStoreRegistration
```

## 8) Firestore Notification Config

Create/update this document:

- Path: `platform_config/notifications`

Suggested initial values (safe defaults):

```json
{
  "email": {
    "enabled": false,
    "fromAddress": "Pocket POS <onboarding@updates.mypocketpos.in>",
    "apiKey": ""
  },
  "sms": {
    "enabled": false,
    "fromNumber": "+14155550123",
    "accountSid": "",
    "authToken": ""
  },
  "whatsapp": {
    "enabled": false,
    "fromNumber": "whatsapp:+14155238886",
    "accountSid": "",
    "authToken": ""
  }
}
```

Notes:

1. Keep all channels disabled by default.
2. Enable only after provider setup is complete.
3. If UI-stored credentials are empty, the function falls back to Firebase Secret Manager values.

## 9) Safe Live Testing Sequence

1. Keep all channels OFF.
2. Register one test store and verify registration remains stable.
3. Enable Email only and test one registration.
4. Review Firestore `notification_logs` entries.
5. Enable SMS/WhatsApp later, one by one.

## 10) Troubleshooting

### A) `Permission denied` while writing config

- Verify your account is in `platform_admins/{uid}`.
- Re-deploy Firestore rules if recently updated.

### B) Function deploy fails due to Node/runtime

- Ensure local Node version supports the configured engine in `functions/package.json`.
- Re-run `npm install` inside `functions`.

### C) Emails/SMS/WhatsApp not sending

1. Confirm channel `enabled` flag is true.
2. Confirm sender fields (`fromAddress`, `fromNumber`) are valid.
3. Confirm credentials are provided either in UI config or in Secret Manager.
4. Check function logs:

```bash
firebase functions:log --only sendWelcomeEmailOnStoreRegistration
```

### D) Registration flow must not break

The function is implemented as best-effort and does not throw failures back into app registration. Delivery errors are logged in `notification_logs`.

## 11) Recommended Security Practice

For production, prefer storing provider credentials in Firebase Secret Manager. Keep Firestore-stored credential fields blank unless you intentionally need UI-managed credentials.
