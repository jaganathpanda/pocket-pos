# Platform Admin: Subscription Plan Deletion Guide

## What Changed

Updated `firestore.rules` to explicitly allow platform admins to delete subscription plans:

**Before:**
```firestore
allow create, update, delete: if isPlatformAdmin();
```

**After:**
```firestore
allow create, update: if isPlatformAdmin();
allow delete: if isPlatformAdmin();
```

---

## Why Deletion Might Fail

Even with correct permissions, plan deletion fails if:

### ❌ Plan is In Use
**Error:** "Plan is currently assigned to active subscriptions"

**Reason:** Can't delete a plan that stores are actively using

**Solution:** 
1. Change all active subscriptions to a different plan first, OR
2. Set the plan to "Inactive" instead of deleting
3. Then delete

**Steps to deactivate instead:**
1. Go to Settings → Platform Subscriptions
2. Find the plan
3. Click the pause icon to deactivate it
4. Plan disappears from public listings but isn't deleted

### ❌ User is Not a Platform Admin
**Error:** "Permission denied" on delete

**Reason:** User not set up as platform admin

**Solution:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Firestore → `platform_admins` collection
3. Verify your UID document exists
4. If not, ask an existing admin to create it

**Check your UID:**
- In Settings → Owner profile
- Your UID is shown in the user details
- OR open browser console: `firebase.auth().currentUser.uid`

---

## Delete vs Deactivate

### Delete (Soft Delete)
- Sets `deletedAt` timestamp
- Plan is hidden from everyone
- Still appears in admin's historical records
- Use when you made a mistake or no longer need the plan

### Deactivate (Hard Deactivate)
- Sets `isActive: false`
- Plan doesn't show on public listing
- Can be reactivated later
- Use for temporary pause

**Recommended:** Use deactivate for most cases, delete only for mistakes

---

## Admin Deletion Steps

### Step 1: Check If Plan is In Use

Go to Settings → Platform Subscriptions

1. Find the plan you want to delete
2. Click preview icon to see details
3. If you see "safe delete" option with no warning, it's safe to delete

### Step 2: Move Subscriptions (If Needed)

If plan is in use:

1. Search for stores using that plan
2. Go to each store
3. Click "Assign subscription" to change their plan
4. Select a different plan
5. Click "Assign"

### Step 3: Delete

1. Find the plan
2. Click delete (trash) icon
3. Confirm: "Delete plan?"
4. Done! Plan is now soft-deleted

---

## Safe Deletion Check

The system prevents deletion if:

```typescript
// In firestore_subscription_repository.dart:
const inUse = await db
  .collectionGroup('customer_subscriptions')
  .where('planId', isEqualTo: planId)
  .where('status', whereIn: ['trialing', 'active', 'past_due'])
  .get();

if (inUse.docs.isNotEmpty) {
  throw Exception('Plan is currently assigned to active subscriptions.');
}
```

**Active statuses that block deletion:**
- `trialing` - In trial period
- `active` - Actively subscribed  
- `past_due` - Payment overdue but not canceled

**Safe to delete if status is:**
- `pending` - Awaiting confirmation
- `canceled` - Already canceled
- `expired` - Already expired

---

## Firestore Permissions Summary

| Operation | Requirement | Notes |
|-----------|-------------|-------|
| **Read (Get/List)** | Platform admin OR public visible plan | Public can only see active + visible + non-deleted |
| **Create** | Platform admin | Create new plans |
| **Update** | Platform admin | Edit existing plans (name, price, features, etc) |
| **Delete** | Platform admin | Soft-delete a plan (sets deletedAt) |

---

## Troubleshooting

### "Permission denied" Error
- [ ] You are logged in as platform admin
- [ ] Go to Firebase Console → Firestore → `platform_admins` collection
- [ ] Your UID document exists
- [ ] If not, ask another admin to add you: Create doc with ID = your UID

### "Plan is in use" Error
- [ ] Reassign stores to different plans
- [ ] Or deactivate the plan instead of deleting
- [ ] Check: Settings → Platform Subscriptions → Search for stores using plan

### Plan Still Shows After Delete
- [ ] It's soft-deleted (sets `deletedAt` timestamp)
- [ ] Still visible in admin records
- [ ] Hidden from public/store owners
- [ ] Use deactivate if you want to hide it immediately

### Can't Edit Plan
- [ ] Same as delete: must be platform admin
- [ ] Check Firestore `platform_admins` collection

---

## Before Deleting: Checklist

- [ ] I am logged in as a platform admin
- [ ] The plan has no active subscriptions
- [ ] I've notified affected stores (if any)
- [ ] I understand this sets `deletedAt` (soft-delete, not hard-delete)
- [ ] I don't need this plan anymore

---

## Reference: Soft Delete vs Hard Delete

**Soft Delete (Current Implementation):**
```javascript
{
  status: 'deleted',  // No longer used
  deletedAt: Timestamp.now(),  // When it was deleted
  isActive: false,
  publicVisible: false,
  // All other fields still in document
}
```

**Benefits:**
- Reversible (can undelete by clearing `deletedAt`)
- Historical records stay intact
- Admin can see deleted plans in history
- Safe for compliance/auditing

---

## Rules Deployed

Deploy the updated rules:

```bash
firebase deploy --only firestore:rules
```

The delete permission for platform admins is now explicit and should work correctly.
