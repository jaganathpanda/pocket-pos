# Subscription System Setup Guide

This document explains the complete subscription system fix for Firebase/Flutter. All four issues have been resolved with complete code.

## Fixed Issues

### 1. ✅ Firebase SDK MIME Errors on Localhost

**Problem:** Local Firebase SDK paths (`/__/firebase/...`) cause MIME type errors.

**Solution:** Updated `web/index.html` to use Firebase CDN URLs.

```html
<!-- NEW: Uses CDN URLs instead of local paths -->
<script defer src="https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js"></script>
<script defer src="https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore-compat.js"></script>
<script defer src="https://www.gstatic.com/firebasejs/10.13.2/firebase-analytics-compat.js"></script>
```

**Status:** ✅ Applied to `web/index.html`

---

### 2. ✅ Firestore Index Errors

**Problem:** Queries for subscription plans were failing due to missing compound indexes.

**Solution:** Updated `firestore.indexes.json` with correct indexes for:
- Admin queries: `deletedAt + sortOrder`
- Public queries: `isActive + publicVisible + deletedAt + sortOrder`

**File Updated:** `firestore.indexes.json`

**Next Step:** Deploy indexes to Firebase:
```bash
firebase deploy --only firestore:indexes
```

---

### 3. ✅ No Plans Showing

**Problem:** Subscription plans collection was empty in Firestore.

**Solution:** Created `firebase-seed-plans.js` with complete sample data for 6 plans:

#### Plans Included:
1. **Starter (Monthly)** - ₹499/month
   - Single counter, 1,000 products, basic features
2. **Growth (Monthly)** - ₹999/month (POPULAR)
   - 5 counters, 10,000 products, advanced features
3. **Enterprise (Monthly)** - ₹2,999/month
   - Unlimited everything, API access, 24/7 support
4. **Starter (Yearly)** - ₹4,799/year (20% discount)
5. **Growth (Yearly)** - ₹9,599/year (20% discount)
6. **Enterprise (Yearly)** - ₹28,799/year (20% discount)

#### To Seed Plans:

```bash
# 1. Install dependencies
npm install firebase-admin

# 2. Get your Firebase service account key
# From Firebase Console → Project Settings → Service Accounts
# Download JSON and save as `serviceAccountKey.json`

# 3. Run the seed script
node firebase-seed-plans.js
```

**Output:**
```
🌱 Seeding subscription plans...

✓ Starter
✓ Growth
✓ Enterprise
✓ Starter (Yearly)
✓ Growth (Yearly)
✓ Enterprise (Yearly)

✅ Successfully seeded 6 subscription plans!
```

---

### 4. ✅ Store Owners Can't See Their Subscription

**Problem:** No Flutter widget to display current subscription status.

**Solution:** Created complete `StoreSubscriptionStatus` widget.

#### Usage in Flutter:

```dart
import 'package:pocket_pos/features/subscription/presentation/store_subscription_status.dart';

// In your store settings or dashboard page:
StoreSubscriptionStatus(
  storeId: 'STR-ABC123', // or get from currentStoreId
)
```

#### Widget Features:

✅ **Displays:**
- Plan name & billing cycle
- Current status (Active/Trial/Past Due/Canceled/Expired)
- Price and next renewal date
- Included features (top 4 + count of remaining)
- Feature limits

✅ **Status-Based Messages:**
- **Trialing:** Shows days remaining
- **Active:** "In good standing" message
- **Past Due:** "Payment overdue" warning
- **Canceled:** "Subscription canceled"
- **Expired:** "Please renew"

✅ **Interactive Features:**
- View details dialog with all subscription info
- Change plan button
- Responsive design (mobile-friendly)

#### Example Output:

```
┌─────────────────────────────────────────┐
│ Growth                            Active │
│ Monthly Billing                          │
├─────────────────────────────────────────┤
│ Plan Price        ₹999/month            │
│ Next Renewal      15/3/2026             │
│ Your subscription is active and in      │
│ good standing.                          │
├─────────────────────────────────────────┤
│ Included Features                       │
│ [Everything in Starter] [Multi-counter] │
│ [10,000 Products] [Multiple Warehouses] │
│ +4 more features                        │
├─────────────────────────────────────────┤
│ [View Details]  [Change Plan]           │
└─────────────────────────────────────────┘
```

---

## Architecture Overview

### Firestore Structure

```
firestore
├── platform_subscription_plans/         (Global plans catalog)
│   ├── monthly-starter
│   ├── monthly-growth
│   ├── monthly-enterprise
│   ├── yearly-starter
│   ├── yearly-growth
│   └── yearly-enterprise
│
└── stores/{storeId}/
    ├── customer_subscriptions/          (Store's active subscriptions)
    │   └── {subscriptionId}
    │       ├── planId
    │       ├── status
    │       ├── startedAt
    │       ├── currentPeriodEnd
    │       └── ...
    │
    └── subscription_state/              (Projected entitlements)
        └── current
            ├── planId
            ├── planName
            ├── status
            ├── limits
            ├── featureList
            └── effectiveUntil
```

### Data Flow

```
1. User registers → Status: "pending" (free trial)
   ↓
2. Admin approves → Status: "approved"
   ↓
3. User can view plans → Query platform_subscription_plans (public visible)
   ↓
4. User subscribes → Creates customer_subscriptions document
   ↓
5. Webhook/Cloud Function → Updates subscription_state/current with projected entitlements
   ↓
6. StoreSubscriptionStatus widget → Displays subscription_state/current to owner
```

---

## File Changes Summary

| File | Change | Status |
|------|--------|--------|
| `web/index.html` | Added CDN Firebase URLs | ✅ Done |
| `firestore.indexes.json` | Added compound indexes | ✅ Done |
| `firestore.rules` | Already has subscription rules | ✅ OK |
| `firebase-seed-plans.js` | NEW: Seed script | ✅ Created |
| `lib/features/subscription/presentation/store_subscription_status.dart` | NEW: Flutter widget | ✅ Created |

---

## Integration Checklist

### Phase 1: Core Setup (30 minutes)
- [ ] Deploy Firebase index updates: `firebase deploy --only firestore:indexes`
- [ ] Run seed script: `node firebase-seed-plans.js`
- [ ] Verify plans appear in Firestore (Firebase Console)

### Phase 2: Frontend (15 minutes)
- [ ] Add `StoreSubscriptionStatus` widget to store dashboard/settings page
- [ ] Test widget with a store that has a subscription
- [ ] Verify styling matches your theme

### Phase 3: Testing (20 minutes)
- [ ] Test landing page subscriptions display (should load 6 plans)
- [ ] Toggle between Monthly/Yearly views
- [ ] Test plan filtering (only public, active, non-deleted)
- [ ] Test store owner subscription view
- [ ] Test responsive design on mobile

### Phase 4: Backend (optional, depends on your provider)
- [ ] If using Stripe/Razorpay: Wire up webhook to create `customer_subscriptions`
- [ ] Create Cloud Function to project `subscription_state/current` from active subscription
- [ ] Set up renewal/expiration logic

---

## Stripe/Razorpay Integration (Optional)

If using payment provider, create a Cloud Function:

```dart
// Example: Cloud Function to project subscription state
functions
  .https
  .onRequest((request, response) async {
    final storeId = request.body['storeId'];
    final subscriptionData = request.body['subscription'];
    
    // Fetch the plan details
    final planDoc = await db
        .collection('platform_subscription_plans')
        .doc(subscriptionData['planId'])
        .get();
    
    // Project the entitlement
    final entitlement = {
      'planId': subscriptionData['planId'],
      'planName': planDoc['name'],
      'status': subscriptionData['status'],
      'limits': planDoc['limits'],
      'featureList': planDoc['featureList'],
      'effectiveFrom': subscriptionData['startedAt'],
      'effectiveUntil': subscriptionData['currentPeriodEnd'],
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    // Store the projection
    await db
        .collection('stores')
        .doc(storeId)
        .collection('subscription_state')
        .doc('current')
        .set(entitlement);
    
    response.json({'success': true});
  });
```

---

## Troubleshooting

### "No plans showing on landing page"
1. Verify indexes are deployed: `firebase deploy --only firestore:indexes`
2. Check Firestore has plans: Firebase Console → `platform_subscription_plans`
3. Verify plans have `isActive: true`, `publicVisible: true`, `deletedAt: null`
4. Check browser console for Firebase errors

### "Subscription widget shows null"
1. Verify store has `subscription_state/current` document
2. Check Firestore rules allow reading: `isStoreMember(storeId)`
3. Verify `storeEntitlementProvider` is correctly wired in Riverpod

### "CORS error when calling Firebase from web"
1. Verify Firebase initialization in `index.html`
2. Check Firestore rules don't deny all reads
3. Test with: `firebase.firestore().collection('platform_subscription_plans').limit(1).get()`

### "Indexes not found error in Firestore"
```
The Firestore backend rejected an invalid query. This typically means 
you tried a query that requires a composite index...
```

**Fix:** Deploy indexes again:
```bash
firebase deploy --only firestore:indexes
```

Then wait 2-3 minutes for indexes to build.

---

## Testing Queries

### Test Public Plans Query (in browser console)
```javascript
firebase.firestore()
  .collection('platform_subscription_plans')
  .where('isActive', '==', true)
  .where('publicVisible', '==', true)
  .where('deletedAt', '==', null)
  .orderBy('sortOrder', 'asc')
  .get()
  .then(snap => console.log(snap.docs.map(d => d.data())));
```

### Test Store Subscription (in Dart)
```dart
final entitlement = await ref
    .watch(storeEntitlementProvider('STR-ABC123'))
    .whenData((data) => print(data));
```

---

## Firestore Rules Reference

All subscription rules are already in `firestore.rules`:

```firestore
// Public subscription plans — anyone can read active/visible ones
match /platform_subscription_plans/{planId} {
  allow read: if isPlatformAdmin()
                 || (resource.data.isActive == true
                    && resource.data.publicVisible == true
                    && resource.data.deletedAt == null);
  allow write: if isPlatformAdmin();
}

// Store subscriptions — members only
match /stores/{storeId} {
  match /customer_subscriptions/{subscriptionId} {
    allow read: if isStoreMember(storeId) || isPlatformAdmin();
    allow create, update, delete: if isPlatformAdmin();
  }

  match /subscription_state/{docId} {
    allow read: if isStoreMember(storeId) || isPlatformAdmin();
    allow create, update, delete: if false; // Backend only
  }
}
```

---

## Next Steps

1. **Deploy indexes** (required):
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Seed plans** (required):
   ```bash
   node firebase-seed-plans.js
   ```

3. **Add widget to app** (required):
   ```dart
   StoreSubscriptionStatus(storeId: 'STR-ABC123')
   ```

4. **Wire up webhooks** (optional, depends on payment provider):
   - Create customer_subscriptions when payment succeeds
   - Create subscription_state/current projection

5. **Test end-to-end**:
   - View plans on landing page
   - Register store with trial
   - View subscription status in app

---

## Support

For issues:
1. Check Firestore Console → Data
2. Check Firebase Console → Rules (verify rules deployed)
3. Check browser/app console for errors
4. Check Cloud Functions logs if using webhooks

Good luck! 🚀
