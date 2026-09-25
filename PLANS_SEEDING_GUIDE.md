# Subscription Plans Seeding Guide

## Why Configuration-Based Seeding?

The refactored script uses a **separate JSON config file** instead of hardcoding. This gives you:

✅ **Easy to maintain** - Edit plans without touching code  
✅ **Version control** - Track plan changes in git history  
✅ **Multiple environments** - Different plans for dev/staging/prod  
✅ **Team collaboration** - Non-developers can modify pricing  
✅ **Backup/restore** - Export/import plan versions  
✅ **Dry-run preview** - See changes before applying  

---

## File Structure

```
project/
├── firebase-plans-config.json    ← Plan definitions (JSON)
└── firebase-seed-plans.js        ← Seeding script (reads from JSON)
```

---

## Quick Start

### 1. Edit Plans (No Code Needed)

Open `firebase-plans-config.json`:

```json
{
  "plans": [
    {
      "id": "monthly-starter",
      "name": "Starter",
      "priceMinor": 49900,  // ← Change price here
      "isActive": true,      // ← Toggle visibility
      "featureList": [       // ← Add/remove features
        "Feature 1",
        "Feature 2"
      ],
      "limits": {
        "max_products": 1000  // ← Adjust limits
      }
      // ... rest of config
    }
  ]
}
```

### 2. Seed Plans

```bash
# Basic seed
node firebase-seed-plans.js

# Preview changes first (dry-run)
node firebase-seed-plans.js --dryrun

# Delete old plans and reseed
node firebase-seed-plans.js --delete

# Use custom config file
node firebase-seed-plans.js --config ./custom-plans.json
```

---

## Command Options

| Option | Purpose | Example |
|--------|---------|---------|
| `--config <path>` | Use alternate config file | `--config ./plans-v2.json` |
| `--delete` | Delete existing plans first | Useful for resetting |
| `--dryrun` | Preview changes without saving | Safe to test |
| (none) | Default: seed from config | `node firebase-seed-plans.js` |

### Examples

```bash
# Seed default plans
node firebase-seed-plans.js

# Preview what will happen
node firebase-seed-plans.js --dryrun

# Reset and reseed from scratch
node firebase-seed-plans.js --delete

# Use a backup config file
node firebase-seed-plans.js --config ./firebase-plans-backup.json

# Combine options: reset + preview
node firebase-seed-plans.js --delete --dryrun
```

---

## Editing Plans

### Change a Price

```json
{
  "id": "monthly-starter",
  "name": "Starter",
  "priceMinor": 49900  // ← ₹499 (priceMinor is in paisa/cents)
}
```

To calculate price in paisa:
- ₹100 = 10,000 paisa
- ₹499 = 49,900 paisa

Use this formula: **₹X = X × 100 paisa**

### Add/Remove a Feature

```json
{
  "featureList": [
    "Unlimited billing",      // ← Existing
    "Barcode scanning",       // ← Add this
    "Advanced reports"        // ← Keep this
    // "API access" removed
  ]
}
```

### Adjust Limits

```json
{
  "limits": {
    "max_products": 1000,          // Single counter
    "max_counters": 1,             // Just 1 counter
    "max_warehouses": 1,           // Just 1 warehouse
    "max_staff": 3,                // Up to 3 staff
    "max_customers": 1000          // Up to 1000 customers
    // Use -1 for unlimited
  }
}
```

### Mark as Popular

```json
{
  "id": "monthly-growth",
  "isPopular": true,        // ← Shows "POPULAR" badge on landing
  "badgeText": "POPULAR",   // ← Custom badge text
  "sortOrder": 2            // ← Higher number = appears later
}
```

### Hide a Plan

```json
{
  "id": "old-plan",
  "isActive": false,          // ← Turns off for everyone
  "publicVisible": false      // ← Hides from public landing page
}
```

---

## Workflow Examples

### Example 1: Launch New Plan

1. **Add to config:**
```json
{
  "id": "monthly-pro",
  "name": "Pro",
  "slug": "pro-monthly",
  "description": "For growing businesses",
  "priceMinor": 149900,  // ₹1,499
  "isActive": false,     // Start inactive
  "publicVisible": false,
  "sortOrder": 2.5,
  // ... rest of fields
}
```

2. **Preview:**
```bash
node firebase-seed-plans.js --dryrun
```

3. **Seed:**
```bash
node firebase-seed-plans.js
```

4. **Test in Firebase Console** to make sure it looks right

5. **Activate when ready:**
```json
{
  "isActive": true,
  "publicVisible": true
}
```

6. **Seed again:**
```bash
node firebase-seed-plans.js
```

### Example 2: Adjust Pricing

1. **Edit prices in config:**
```json
{
  "id": "monthly-starter",
  "priceMinor": 59900  // ₹599 (was ₹499)
}
```

2. **Preview changes:**
```bash
node firebase-seed-plans.js --dryrun
```

3. **Apply:**
```bash
node firebase-seed-plans.js
```

### Example 3: Reset Everything

If you mess up, reset and start fresh:

```bash
# Backup current config first
cp firebase-plans-config.json firebase-plans-backup.json

# Reset and reseed
node firebase-seed-plans.js --delete

# Restore from backup if needed
cp firebase-plans-backup.json firebase-plans-config.json
node firebase-seed-plans.js --delete
```

---

## Dry-Run Output

Run `node firebase-seed-plans.js --dryrun` to see what will be seeded:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Firebase Subscription Plans Seeder
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 Loading config from: ./firebase-plans-config.json
   Found 6 plan(s)

🌱 Seeding 6 subscription plan(s)...
   (DRY RUN - no changes will be made)

   ✓ Starter
      ID: monthly-starter
      Price: ₹499.00 (monthly)
      Active: true, Visible: true

   ✓ Growth
      ID: monthly-growth
      Price: ₹999.00 (monthly)
      Active: true, Visible: true

   ✓ Enterprise
      ID: monthly-enterprise
      Price: ₹2,999.00 (monthly)
      Active: true, Visible: true

   ... (3 more)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Config File Format

### Full Plan Schema

```json
{
  "id": "monthly-starter",              // Unique ID (required)
  "name": "Starter",                    // Display name (required)
  "slug": "starter-monthly",            // URL slug
  "description": "Perfect for...",      // Shown on landing page
  "billingCycle": "monthly",            // "monthly" or "yearly"
  "priceMinor": 49900,                  // Price in paisa (₹499)
  "currency": "INR",                    // Currency code
  "sortOrder": 1,                       // Display order (1=first)
  "isActive": true,                     // Enabled/disabled
  "publicVisible": true,                // Show on landing page
  "isPopular": false,                   // Highlight as popular
  "trialDays": 7,                       // Free trial duration
  "badgeText": null,                    // Badge text ("POPULAR", "SAVE 20%", etc)
  "ctaLabel": null,                     // Button text ("Start now", "Sign up", etc)
  "ctaUrl": null,                       // Button link
  "defaultForNewStores": true,          // Default for new registrations
  "featureList": [                      // List of features
    "Unlimited billing",
    "Basic inventory"
  ],
  "limits": {                           // Usage limits (-1 = unlimited)
    "max_products": 1000,
    "max_counters": 1,
    "max_warehouses": 1,
    "max_staff": 3,
    "max_customers": 1000
  }
}
```

---

## Troubleshooting

### "Config file not found"

```bash
# Make sure file exists in current directory
ls firebase-plans-config.json

# Or specify full path
node firebase-seed-plans.js --config /full/path/firebase-plans-config.json
```

### "Failed to seed plans" Error

Check:
1. **Service account key:** Is `serviceAccountKey.json` present?
2. **Firebase project:** Does `serviceAccountKey.json` match your Firebase project?
3. **Required fields:** Does every plan have `id`, `name`, `priceMinor`?
4. **JSON syntax:** Is the JSON valid? (use online JSON validator)

### "Permission denied" Error

Your service account needs these permissions:
- Firestore write access
- Project Editor role

Fix:
1. Go to Firebase Console → IAM
2. Find your service account
3. Add "Editor" role

### Want to See What's in Firestore?

Go to [Firebase Console](https://console.firebase.google.com/) → Firestore → `platform_subscription_plans` collection

---

## Environment-Specific Configs

### Development Setup

```bash
# Dev plans with low prices for testing
node firebase-seed-plans.js --config ./plans-dev.json

# Example plans-dev.json:
# {
#   "plans": [
#     { "id": "monthly-starter", "priceMinor": 1000 },  // ₹10
#     { "id": "monthly-growth", "priceMinor": 5000 }    // ₹50
#   ]
# }
```

### Production Setup

```bash
# Real pricing
node firebase-seed-plans.js --config ./firebase-plans-config.json
```

### Staging Setup

```bash
# Same as production but marked differently
node firebase-seed-plans.js --config ./plans-staging.json
```

---

## Git Workflow

### Scenario: Team Updates Pricing

**Person A (Product Manager):**
```bash
# Edit prices in config
# firebase-plans-config.json
{
  "id": "monthly-growth",
  "priceMinor": 119900  // Increase to ₹1,199
}

# Commit changes
git add firebase-plans-config.json
git commit -m "Update Growth plan pricing: ₹999 → ₹1,199"
git push
```

**Person B (Developer):**
```bash
# Pull the updated config
git pull

# Preview what changed
node firebase-seed-plans.js --dryrun

# Apply to Firestore
node firebase-seed-plans.js
```

---

## Backing Up Plans

### Export Current Plans

```bash
# Manual export via Firebase Console
# Firestore → platform_subscription_plans → Export Collection

# Or use the CLI
firebase firestore:export ./firestore-backup --project=pocketpos-firebase
```

### Import Backup

```bash
# Restore from backup
firebase firestore:import ./firestore-backup --project=pocketpos-firebase
```

---

## Migration: From Hardcoded to Config-Based

If upgrading from the old hardcoded version:

```bash
# 1. Delete old plans
firebase firestore:delete platform_subscription_plans --project=pocketpos-firebase --recursive

# 2. Seed from new config
node firebase-seed-plans.js
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Seed plans | `node firebase-seed-plans.js` |
| Preview first | `node firebase-seed-plans.js --dryrun` |
| Reset & reseed | `node firebase-seed-plans.js --delete` |
| Use custom config | `node firebase-seed-plans.js --config ./plans.json` |
| View plans | Firebase Console → Firestore → `platform_subscription_plans` |
| Edit plans | Edit `firebase-plans-config.json` (no code!) |
| Change pricing | Edit `priceMinor` in JSON |

---

## Next Steps

1. ✅ Edit `firebase-plans-config.json` with your pricing
2. ✅ Run `node firebase-seed-plans.js --dryrun` to preview
3. ✅ Run `node firebase-seed-plans.js` to seed
4. ✅ Verify in Firebase Console
5. ✅ Commit changes: `git commit -m "Seed subscription plans"`

Done! Your plans are now in Firestore. 🚀
