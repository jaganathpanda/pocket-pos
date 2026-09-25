/**
 * Firebase Firestore Seed Script - Subscription Plans
 *
 * Usage: node firebase-seed-plans.js [--config <path>] [--delete] [--dryrun]
 *
 * Options:
 *   --config <path>  : Path to plans config JSON (default: firebase-plans-config.json)
 *   --delete         : Delete all existing plans before seeding
 *   --dryrun         : Show what would be seeded without actually writing to Firestore
 *
 * Examples:
 *   node firebase-seed-plans.js
 *   node firebase-seed-plans.js --config ./plans-backup.json
 *   node firebase-seed-plans.js --delete  (reset and reseed)
 *   node firebase-seed-plans.js --dryrun  (preview changes)
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const configPath = args.includes('--config')
  ? args[args.indexOf('--config') + 1]
  : './firebase-plans-config.json';
const shouldDelete = args.includes('--delete');
const isDryrun = args.includes('--dryrun');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id || 'pocketpos-firebase'
});

const db = admin.firestore();

async function loadConfig() {
  try {
    const configFile = path.resolve(configPath);
    if (!fs.existsSync(configFile)) {
      throw new Error(`Config file not found: ${configFile}`);
    }
    const content = fs.readFileSync(configFile, 'utf-8');
    const config = JSON.parse(content);
    if (!config.plans || !Array.isArray(config.plans)) {
      throw new Error('Config must contain a "plans" array');
    }
    return config.plans;
  } catch (error) {
    console.error('❌ Failed to load config:', error.message);
    process.exit(1);
  }
}

async function deleteExistingPlans() {
  console.log('🗑️  Deleting existing plans...');
  const plansCol = db.collection('platform_subscription_plans');
  const snapshot = await plansCol.get();

  if (snapshot.empty) {
    console.log('   (no existing plans found)\n');
    return;
  }

  const batch = db.batch();
  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log(`   Deleted ${snapshot.size} plan(s)\n`);
}

function preparePlanData(plan) {
  // Add timestamps
  return {
    ...plan,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    deletedAt: null
  };
}

async function seedPlans(plans) {
  console.log(`🌱 Seeding ${plans.length} subscription plan(s)...`);

  if (isDryrun) {
    console.log('   (DRY RUN - no changes will be made)\n');
    plans.forEach(plan => {
      console.log(`   ✓ ${plan.name}`);
      console.log(`      ID: ${plan.id}`);
      console.log(`      Price: ₹${(plan.priceMinor / 100).toFixed(2)} (${plan.billingCycle})`);
      console.log(`      Active: ${plan.isActive}, Visible: ${plan.publicVisible}`);
    });
    console.log();
    return;
  }

  const batch = db.batch();
  const plansCol = db.collection('platform_subscription_plans');

  plans.forEach((plan) => {
    // Validate required fields
    if (!plan.id) throw new Error('Plan missing required field: id');
    if (!plan.name) throw new Error('Plan missing required field: name');
    if (plan.priceMinor === undefined) throw new Error('Plan missing required field: priceMinor');

    const docRef = plansCol.doc(plan.id);
    const planData = preparePlanData(plan);
    batch.set(docRef, planData);
    console.log(`   ✓ ${plan.name}`);
  });

  try {
    await batch.commit();
    console.log(`\n✅ Successfully seeded ${plans.length} subscription plan(s)!`);
  } catch (error) {
    console.error('\n❌ Error seeding plans:', error);
    throw error;
  }
}

async function main() {
  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('Firebase Subscription Plans Seeder');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Load config
    console.log(`📄 Loading config from: ${configPath}`);
    const plans = await loadConfig();
    console.log(`   Found ${plans.length} plan(s)\n`);

    // Delete existing if requested
    if (shouldDelete) {
      await deleteExistingPlans();
    }

    // Seed plans
    await seedPlans(plans);

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    process.exit(1);
  }
}

main();
