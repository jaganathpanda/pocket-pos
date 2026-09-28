# Subscription Visibility Troubleshooting

## Problem: Store Owners Can't See Their Subscription

If store owners see "No Active Subscription" or a loading spinner that never completes, follow this guide.

---

## Diagnostic Checklist

### ✅ Step 1: Verify Widget is Integrated

**File:** `lib/features/settings/presentation/settings_page.dart`

Check if `StoreSubscriptionStatus` is imported and displayed:

```dart
import '../../subscription/presentation/store_subscription_status.dart';

// In build():
StoreSubscriptionStatus(storeId: storeId)
```

**Status:** ✅ Already added in Settings page

---

### ✅ Step 2: Verify Firestore Rules Allow Reading

**File:** `firestore.rules`

Check that subscription rules are in place:

```firestore
match /stores/{storeId} {
  match /subscription_state/{docId} {
    allow read: if isStoreMember(storeId) || isPlatformAdmin();
    allow create, update, delete: if false;  // Backend only
  }
}
```

**Status:** Already in rules ✅

---

### ⚠️ Step 3: Check If subscription_state/current Exists

This is the CRITICAL step. The `subscription_state/current` document must exist in Firestore.

**How to Check:**

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Navigate: Firestore → `stores` → [StoreId] → `subscription_state`
3. Look for a document called `current`

**If it DOES exist:** ✅ Move to Step 4

**If it DOES NOT exist:** ❌ Need to create it (see "Create Missing Document" below)

---

## Fix: Create Missing subscription_state/current Document

If the document doesn't exist, you need a **Cloud Function** to create it automatically.

### Option A: Manual Creation (Quick Fix)

1. **Firebase Console** → Firestore
2. Navigate to: `stores/[StoreId]/subscription_state/`
3. Click "Add Document"
4. Set document ID: `current`
5. Add these fields:

```json
{
  "status": "active",
  "planId": "monthly-starter",
  "planName": "Starter",
  "billingCycle": "monthly",
  "priceMinor": 49900,
  "currency": "INR",
  "featureList": [
    "Unlimited billing",
    "Basic inventory",
    "Single counter"
  ],
  "limits": {
    "max_products": 1000,
    "max_counters": 1,
    "max_warehouses": 1,
    "max_staff": 3,
    "max_customers": 1000
  },
  "effectiveFrom": [Current timestamp],
  "effectiveUntil": [Future timestamp - 30 days],
  "sourceSubscriptionId": "initial-trial",
  "updatedAt": [Current timestamp]
}
```

### Option B: Automated (Recommended)

Create a Cloud Function to automatically create this document when a store is approved:

**File:** `functions/subscriptions.js`

```javascript
/**
 * Creates a default subscription_state/current document when a store is approved.
 * Triggered by: Store status changes to "approved"
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.onStoreApproved = functions.firestore
  .document('stores/{storeId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const storeId = context.params.storeId;

    // Only trigger when status changes to "approved"
    if (before.status === 'approved' || after.status !== 'approved') {
      return null;
    }

    console.log(`Creating subscription_state/current for ${storeId}`);

    try {
      // Get the default plan (Starter)
      const planDoc = await db
        .collection('platform_subscription_plans')
        .doc('monthly-starter')
        .get();

      if (!planDoc.exists) {
        console.error('Default plan not found');
        return null;
      }

      const plan = planDoc.data();

      // Create the entitlement document
      const trialEndDate = new Date();
      trialEndDate.setDate(trialEndDate.getDate() + 7); // 7-day trial

      const entitlement = {
        status: 'trialing',  // Start with trial
        planId: plan.id,
        planName: plan.name,
        billingCycle: plan.billingCycle,
        priceMinor: plan.priceMinor,
        currency: plan.currency,
        featureList: plan.featureList,
        limits: plan.limits,
        effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
        effectiveUntil: admin.firestore.Timestamp.fromDate(trialEndDate),
        sourceSubscriptionId: 'welcome-trial',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Write to Firestore
      await db
        .collection('stores')
        .doc(storeId)
        .collection('subscription_state')
        .doc('current')
        .set(entitlement);

      console.log(`✅ Created subscription_state/current for ${storeId}`);
      return { success: true };
    } catch (error) {
      console.error(`❌ Error creating subscription_state for ${storeId}:`, error);
      throw error;
    }
  });
```

**Deploy:**
```bash
firebase deploy --only functions:onStoreApproved
```

---

## Step 4: Verify Widget Can Read the Document

Once `subscription_state/current` exists, test if the widget can read it:

### Test in Flutter

```dart
// Add this to a test page temporarily
final entitlementAsync = ref.watch(storeEntitlementProvider('STR-ABC123'));

entitlementAsync.when(
  data: (entitlement) {
    print('✅ Subscription loaded: ${entitlement?.planName}');
  },
  loading: () {
    print('⏳ Loading subscription...');
  },
  error: (error, stack) {
    print('❌ Error loading subscription: $error');
  },
);
```

### Test in Firestore Console

1. Firestore → `stores/[StoreId]/subscription_state/current`
2. You should see the document with fields

---

## Common Issues & Solutions

### Issue 1: "No Active Subscription" Message

**Cause:** `subscription_state/current` document doesn't exist

**Fix:** 
1. Check Firestore Console (see Step 3)
2. Create document manually (Option A) or
3. Deploy Cloud Function (Option B)

---

### Issue 2: Spinner Keeps Loading

**Cause:** Document exists but provider can't read it OR Firestore rules deny access

**Fix:**
1. Verify Firestore rules (check subscription_state rules in `firestore.rules`)
2. Test read permission: Open Firebase Console, navigate to the document
3. If you can't see it, rules are blocking → ask admin to fix

---

### Issue 3: "Error Loading Subscription" Card

**Cause:** Provider encountered an error

**Check:**
1. Is `activeStoreIdProvider` working? (the store ID should be populated)
2. Is the storeId being passed correctly to the widget?
3. Check Flutter console for the actual error message

**Debug:**
```dart
// Add this in settings_page.dart to see the storeId
print('DEBUG: storeId = $storeId');
```

---

### Issue 4: Widget Shows But Data is Wrong

**Cause:** `subscription_state/current` document has incorrect data

**Fix:**
1. Go to Firestore Console
2. Edit the document to match the plan details
3. Or delete and let the Cloud Function recreate it

---

## Complete Verification Script

Run this to check all pieces:

```bash
#!/bin/bash

echo "🔍 Subscription System Diagnostic"
echo "=================================="
echo ""

# 1. Check if plans exist
echo "1️⃣  Checking subscription plans..."
firebase firestore:query platform_subscription_plans --limit=1 --pretty 2>/dev/null || echo "⚠️  Plans not found"
echo ""

# 2. Check if specific store has subscription_state
echo "2️⃣  Checking store subscription_state..."
firebase firestore:query stores/STR-ABC123/subscription_state --limit=1 --pretty 2>/dev/null || echo "⚠️  No subscription_state"
echo ""

# 3. Check Firestore rules are deployed
echo "3️⃣  Checking Firestore rules..."
firebase rules:list 2>/dev/null | grep -i subscript || echo "⚠️  Rules status unknown"
echo ""

echo "✅ Diagnostic complete. Check results above."
```

---

## Data Model Reference

### subscription_state/current Schema

```typescript
{
  status: 'trialing' | 'active' | 'pastDue' | 'canceled' | 'expired' | 'pending',
  planId: string,                    // e.g., "monthly-starter"
  planName: string,                  // e.g., "Starter"
  billingCycle: 'monthly' | 'yearly',
  priceMinor: number,                // Price in paisa (₹499 = 49900)
  currency: 'INR',
  featureList: string[],             // List of features
  limits: {
    max_products: number,            // -1 for unlimited
    max_counters: number,
    max_warehouses: number,
    max_staff: number,
    max_customers: number
  },
  effectiveFrom: Timestamp,          // When subscription starts
  effectiveUntil: Timestamp,         // When subscription ends
  sourceSubscriptionId?: string,     // e.g., "stripe-sub-12345"
  updatedAt: Timestamp
}
```

---

## Testing Checklist

- [ ] Store created and approved
- [ ] `subscription_state/current` document exists in Firestore
- [ ] Document has all required fields
- [ ] Widget imported in settings_page.dart
- [ ] Widget displays (not loading spinner)
- [ ] Status shows correctly (Active/Trial/etc)
- [ ] Plan name and price display correctly
- [ ] Features list shows (at least some features)
- [ ] "View Details" and "Change Plan" buttons work

---

## If Still Not Working

1. **Check the Flutter console** for error messages
2. **Enable Firestore logs** in Firebase Console for debugging
3. **Verify user is store member**: User should be in `stores/[StoreId]/users/[uid]`
4. **Check auth state**: User should be signed in
5. **Try different store**: Test with another store ID

---

## Contact/Debug

Add this to temporarily log more info:

```dart
// In store_subscription_status.dart, add to build():
print('DEBUG: storeId=$storeId');
print('DEBUG: entitlementAsync=$entitlementAsync');

// Or in subscriptionRepositoryProvider:
Stream<StoreEntitlement?> watchStoreEntitlement(String storeId) {
  print('DEBUG: watchStoreEntitlement($storeId)');
  return _storeEntitlementDoc(storeId)
      .snapshots()
      .map((snap) {
        print('DEBUG: snapshot=${snap.data()}');
        final data = snap.data();
        if (data == null) {
          print('DEBUG: No data found!');
          return null;
        }
        return StoreEntitlement.fromMap(storeId, data);
      });
}
```

Then check Flutter console output.
