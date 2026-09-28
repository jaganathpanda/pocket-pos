# Subscription Cloud Functions Deployment Guide

## What Changed

Two Twilio secrets were commented out in `functions/index.js` since we're only deploying subscription functions (not SMS).

**File:** `functions/index.js`

```javascript
// Before:
const resendApiKey = defineSecret("RESEND_API_KEY");
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");  // ❌ Error
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");    // ❌ Error

// After:
const resendApiKey = defineSecret("RESEND_API_KEY");
// Commented out - enable when setting up Twilio SMS
// const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
// const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
```

---

## Deploy Steps

### 1. Login to Firebase

```bash
firebase login
```

This will open a browser and authenticate you with Google.

### 2. Deploy Subscription Functions Only

```bash
cd /path/to/mypocketpos
firebase deploy --only functions:onStoreApproved,functions:projectSubscriptionState
```

### 3. Verify Deployment

Look for output like:
```
✔ functions[onStoreApproved(us-central1)]: Successful create operation.
✔ functions[projectSubscriptionState(us-central1)]: Successful create operation.

✔ Deploy complete!
```

---

## What Gets Deployed

### Function 1: `onStoreApproved`
**Trigger:** When store status changes to "approved"

**What it does:**
- Fetches the default "monthly-starter" plan
- Creates `subscription_state/current` document
- Sets 7-day free trial
- Store owners immediately see "Starter Plan · Trialing · 7 days"

---

### Function 2: `projectSubscriptionState`
**Trigger:** When `customer_subscriptions` is created/updated

**What it does:**
- Detects when admin assigns a new plan to a store
- Fetches plan details from `platform_subscription_plans`
- Projects/merges into `subscription_state/current`
- Store owners see updated plan immediately

---

## Troubleshooting

### "The caller does not have permission"
You need Firebase project access. Ask your Firebase project owner to:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `pocketpos-firebase`
3. Go to IAM & Admin → IAM
4. Add your email with "Editor" role

Then try deploying again.

### "TWILIO_ACCOUNT_SID not found"
This is expected - we commented out Twilio since it wasn't being used. If you need SMS later:
1. Uncomment the secret definitions in `functions/index.js`
2. Set up the secrets:
   ```bash
   firebase functions:secrets:set TWILIO_ACCOUNT_SID
   firebase functions:secrets:set TWILIO_AUTH_TOKEN
   ```

### "functions already exist"
If deploying again, just run the same command - it will update existing functions.

---

## After Deployment

### Test Store Approval Flow

1. Create a new store (or use existing)
2. Mark as "approved"
3. Check Firestore:
   - Should see `subscription_state/current` created with trial plan
4. Login as store owner
5. Go to Settings
6. Should see "Starter Plan · Trialing · 7 days"

### Test Admin Assignment Flow

1. Go to Settings → Platform Subscriptions
2. Enter a store ID
3. Click "Assign subscription"
4. Select "Growth" plan, status "Active", duration "30"
5. Click "Assign"
6. Check Firestore:
   - `customer_subscriptions` created
   - `subscription_state/current` updated to "Growth"
7. Store owner (in Settings) sees plan updated to "Growth"

---

## Cloud Function Logs

Monitor function execution:

```bash
firebase functions:log
```

Or in [Firebase Console](https://console.firebase.google.com/):
- Cloud Functions → Logs
- Filter by function name

---

## Rollback (If Needed)

If something goes wrong, delete the functions:

```bash
firebase functions:delete onStoreApproved projectSubscriptionState
```

Then redeploy after fixing:

```bash
firebase deploy --only functions:onStoreApproved,functions:projectSubscriptionState
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Login to Firebase | `firebase login` |
| Deploy subscription functions | `firebase deploy --only functions:onStoreApproved,functions:projectSubscriptionState` |
| View function logs | `firebase functions:log` |
| Delete a function | `firebase functions:delete onStoreApproved` |
| List all functions | `firebase functions:list` |

---

## Next Steps After Deployment

1. ✅ Deploy subscription functions (this guide)
2. ✅ Test store approval → auto creates trial subscription
3. ✅ Test admin assignment → updates store owner's view
4. ✅ Monitor Cloud Function logs for any errors
5. (Optional) Set up Twilio secrets if you need SMS notifications

---

## Additional Resources

- [Firebase Cloud Functions Guide](https://firebase.google.com/docs/functions)
- [Firestore Triggers](https://firebase.google.com/docs/functions/firestore-events)
- [Cloud Function Logging](https://firebase.google.com/docs/functions/writing-and-viewing-logs)
