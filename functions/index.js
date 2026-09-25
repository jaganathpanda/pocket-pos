const { onDocumentCreated, onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { Resend } = require("resend");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const resendApiKey = defineSecret("RESEND_API_KEY");
const INFO_EMAIL = "info@mypocketpos.in";

// ==========================================
// HELPER FUNCTIONS
// ==========================================

function parseChannelConfig(map, key) {
  if (!map || typeof map !== "object") {
    return { enabled: false, fromAddress: null, fromNumber: null };
  }
  const channel = map[key];
  if (!channel || typeof channel !== "object") {
    return { enabled: false, fromAddress: null, fromNumber: null };
  }

  const fromAddress =
    typeof channel.fromAddress === "string" && channel.fromAddress.trim().length > 0
      ? channel.fromAddress.trim()
      : null;
  const fromNumber =
    typeof channel.fromNumber === "string" && channel.fromNumber.trim().length > 0
      ? channel.fromNumber.trim()
      : null;
  const apiKey =
    typeof channel.apiKey === "string" && channel.apiKey.trim().length > 0
      ? channel.apiKey.trim()
      : null;

  return {
    enabled: channel.enabled === true,
    fromAddress,
    fromNumber,
    apiKey,
  };
}

function readEmailFeatureFlags(map) {
  return parseChannelConfig(map, "email");
}

function readSecretValue(secretParam) {
  try {
    const value = secretParam.value();
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
  } catch (_) {
    return null;
  }
}

async function appendNotificationLog(entry) {
  await db.collection("notification_logs").add({
    ...entry,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function readTimestamp(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function deriveSubscriptionStatus(rawStatus, now, periodEnd, trialEnd) {
  const status = typeof rawStatus === "string" && rawStatus.trim().length > 0
    ? rawStatus.trim()
    : "pending";

  const effectiveEnd = periodEnd || trialEnd;
  if (status === "trialing" && effectiveEnd && effectiveEnd < now) {
    return "expired";
  }
  if (status === "active" && effectiveEnd && effectiveEnd < now) {
    return "past_due";
  }
  return status;
}

/**
 * Projects store subscription state without causing recursive function triggers.
 */
async function projectStoreSubscriptionState(storeId) {
  const now = new Date();
  
  const subsSnap = await db
    .collection("stores")
    .doc(storeId)
    .collection("customer_subscriptions")
    .orderBy("updatedAt", "desc")
    .limit(40)
    .get();

  const preferredStatuses = ["trialing", "active", "past_due", "pending", "canceled", "expired"];
  let chosen = null;
  for (const status of preferredStatuses) {
    chosen = subsSnap.docs.find((doc) => {
      const data = doc.data() || {};
      return (data.status || "pending") === status;
    });
    if (chosen) break;
  }

  const entitlementRef = db
    .collection("stores")
    .doc(storeId)
    .collection("subscription_state")
    .doc("current");

  if (!chosen) {
    await entitlementRef.set(
      {
        status: "pending",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await db.collection("stores").doc(storeId).set(
      {
        subscriptionStatus: "pending",
        subscriptionPlanId: admin.firestore.FieldValue.delete(),
        subscriptionCurrentPeriodEnd: admin.firestore.FieldValue.delete(),
        subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  const chosenData = chosen.data() || {};
  const planId = chosenData.planId;
  if (typeof planId !== "string" || planId.trim().length === 0) {
    return;
  }

  const planDoc = await db.collection("platform_subscription_plans").doc(planId).get();
  if (!planDoc.exists) {
    await entitlementRef.set(
      {
        status: "pending",
        planId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  const plan = planDoc.data() || {};
  const periodEnd = readTimestamp(chosenData.currentPeriodEnd);
  const trialEnd = readTimestamp(chosenData.trialEndAt);
  const computedStatus = deriveSubscriptionStatus(
    chosenData.status,
    now,
    periodEnd,
    trialEnd
  );

  // INFINITE LOOP GUARD: Only update customer_subscriptions if status actually changed
  if (chosenData.status !== computedStatus) {
    await chosen.ref.set(
      {
        status: computedStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await entitlementRef.set(
    {
      status: computedStatus,
      planId,
      planName: plan.name || plan.slug || "",
      billingCycle: plan.billingCycle || "monthly",
      priceMinor: Number.isFinite(plan.priceMinor) ? plan.priceMinor : 0,
      currency: typeof plan.currency === "string" ? plan.currency : "INR",
      featureList: Array.isArray(plan.featureList) ? plan.featureList : [],
      limits: typeof plan.limits === "object" && plan.limits !== null ? plan.limits : {},
      effectiveFrom: chosenData.currentPeriodStart || chosenData.startedAt || null,
      effectiveUntil: chosenData.currentPeriodEnd || chosenData.trialEndAt || null,
      sourceSubscriptionId: chosen.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.collection("stores").doc(storeId).set(
    {
      subscriptionStatus: computedStatus,
      subscriptionPlanId: planId,
      subscriptionCurrentPeriodEnd: chosenData.currentPeriodEnd || chosenData.trialEndAt || null,
      subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

// ==========================================
// STORE ONBOARDING & EMAIL TRIGGERS
// ==========================================

exports.sendWelcomeEmailOnStoreRegistration = onDocumentCreated(
  {
    document: "stores/{storeId}",
    region: "asia-south1",
    secrets: [resendApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const storeSnap = event.data;
    if (!storeSnap) {
      logger.warn("Store create event had no snapshot data.");
      return;
    }

    const storeId = event.params.storeId;
    const store = storeSnap.data() || {};
    const ownerEmail = typeof store.email === "string" ? store.email.trim() : "";

    let config;
    try {
      const cfgSnap = await db.collection("platform_config").doc("notifications").get();
      config = cfgSnap.data();
    } catch (err) {
      logger.error("Failed to read notification config; treating as disabled.", {
        storeId,
        error: String(err),
      });
      return;
    }

    const emailCfg = readEmailFeatureFlags(config);
    const defaultResendApiKey = readSecretValue(resendApiKey);

    const storeName = typeof store.name === "string" && store.name.trim().length > 0 ? store.name.trim() : storeId;
    const ownerName = typeof store.ownerName === "string" && store.ownerName.trim().length > 0 ? store.ownerName.trim() : "Store Owner";
    const ownerUsername = typeof store.ownerUsername === "string" && store.ownerUsername.trim().length > 0 ? store.ownerUsername.trim() : "";

    const fromAddress = emailCfg.fromAddress || "Pocket POS <onboarding@updates.mypocketpos.in>";
    const emailSubject = `Welcome to Pocket POS - ${storeId}`;
    const plainBody = [
      `Hi ${ownerName},`,
      "",
      `Welcome to Pocket POS for "${storeName}".`,
      `Your Store ID is: ${storeId}`,
      "",
      "Your store is currently pending platform approval.",
      "Once approved, you can log in and start billing.",
      "",
      "Regards,",
      "Pocket POS Team",
    ].join("\n");

    const htmlBody = `
      <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #222;">
        <p>Hi ${ownerName},</p>
        <p>Welcome to Pocket POS for <strong>${storeName}</strong>.</p>
        <p>Your Store ID is: <strong>${storeId}</strong></p>
        <p>Your Store Username is: <strong>${ownerUsername}</strong></p>
        <p>Your store is currently pending platform approval.<br/>Once approved, you can log in and start billing.</p>
        <p>Regards,<br/>Pocket POS Team</p>
      </div>
    `;

    const tasks = [];

    if (emailCfg.enabled) {
      if (!ownerEmail) {
        tasks.push(
          appendNotificationLog({
            channel: "email",
            template: "welcome_registration",
            storeId,
            status: "skipped",
            reason: "missing_owner_email",
          })
        );
      } else {
        tasks.push((async () => {
          try {
            const effectiveEmailApiKey = emailCfg.apiKey || defaultResendApiKey;
            if (!effectiveEmailApiKey) {
              throw new Error("Missing Resend API key for email channel.");
            }
            const resend = new Resend(effectiveEmailApiKey);
            await resend.emails.send({
              from: fromAddress,
              to: [ownerEmail],
              cc: [INFO_EMAIL],
              subject: emailSubject,
              text: plainBody,
              html: htmlBody,
            });

            await appendNotificationLog({
              channel: "email",
              template: "welcome_registration",
              storeId,
              to: ownerEmail,
              cc: [INFO_EMAIL],
              status: "sent",
            });
          } catch (err) {
            logger.error("Welcome email send failed.", {
              storeId,
              to: ownerEmail,
              error: String(err),
            });

            await appendNotificationLog({
              channel: "email",
              template: "welcome_registration",
              storeId,
              to: ownerEmail,
              cc: [INFO_EMAIL],
              status: "failed",
              error: String(err),
            });
          }
        })());
      }
    } else {
      tasks.push(
        appendNotificationLog({
          channel: "email",
          template: "welcome_registration",
          storeId,
          status: "skipped",
          reason: "feature_disabled",
        })
      );
    }

    await Promise.allSettled(tasks);
  }
);

exports.bootstrapStoreTrialSubscription = onDocumentCreated(
  {
    document: "stores/{storeId}",
    region: "asia-south1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const storeId = event.params.storeId;
    try {
      const storeData = event.data?.data() || {};
      const ownerUid = storeData.ownerUid;

      const plansSnap = await db
        .collection("platform_subscription_plans")
        .where("defaultForNewStores", "==", true)
        .where("isActive", "==", true)
        .where("deletedAt", "==", null)
        .orderBy("sortOrder")
        .limit(1)
        .get();

      if (plansSnap.empty) return;
      const planDoc = plansSnap.docs[0];
      const plan = planDoc.data() || {};
      const trialDays = Number.isFinite(plan.trialDays) ? plan.trialDays : 0;
      const safeTrialDays = trialDays > 0 ? trialDays : 14;

      const now = admin.firestore.Timestamp.now();
      const end = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + safeTrialDays * 24 * 60 * 60 * 1000)
      );

      await db
        .collection("stores")
        .doc(storeId)
        .collection("customer_subscriptions")
        .doc("bootstrap_trial")
        .set(
          {
            storeId,
            planId: planDoc.id,
            status: "trialing",
            source: "backend",
            provider: "none",
            cancelAtPeriodEnd: false,
            startedAt: now,
            trialEndAt: end,
            currentPeriodStart: now,
            currentPeriodEnd: end,
            metadata: {
              seeded: true,
              assignedBy: "bootstrapStoreTrialSubscription",
              ownerUid: typeof ownerUid === "string" ? ownerUid : null,
            },
            createdAt: now,
            updatedAt: now,
          },
          { merge: true }
        );

      await projectStoreSubscriptionState(storeId);
    } catch (error) {
      logger.error("Store trial bootstrap failed", {
        storeId,
        error: String(error),
      });
    }
  }
);

// ==========================================
// SUBSCRIPTION TRIGGERS & PROJECTIONS
// ==========================================

exports.syncStoreSubscriptionProjection = onDocumentWritten(
  {
    document: "stores/{storeId}/customer_subscriptions/{subscriptionId}",
    region: "asia-south1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const storeId = event.params.storeId;
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (
      beforeData &&
      afterData &&
      beforeData.status === afterData.status &&
      beforeData.planId === afterData.planId &&
      beforeData.currentPeriodEnd?.isEqual(afterData.currentPeriodEnd)
    ) {
      return;
    }

    try {
      await projectStoreSubscriptionState(storeId);
    } catch (error) {
      logger.error("Subscription projection sync failed", {
        storeId,
        error: String(error),
      });
    }
  }
);

exports.onPlatformSubscriptionPlanUpdated = onDocumentUpdated(
  {
    document: "platform_subscription_plans/{planId}",
    region: "asia-south1",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (event) => {
    const planId = event.params.planId;
    const beforePlan = event.data?.before?.data() || {};
    const afterPlan = event.data?.after?.data() || {};

    const featuresChanged = JSON.stringify(beforePlan.featureList) !== JSON.stringify(afterPlan.featureList);
    const limitsChanged = JSON.stringify(beforePlan.limits) !== JSON.stringify(afterPlan.limits);
    const nameChanged = beforePlan.name !== afterPlan.name;
    const priceChanged = beforePlan.priceMinor !== afterPlan.priceMinor;

    if (!featuresChanged && !limitsChanged && !nameChanged && !priceChanged) {
      logger.info(`Plan ${planId} updated, but no entitlement-relevant fields changed.`);
      return;
    }

    logger.info(`Plan ${planId} updated. Propagating to active subscriptions...`);

    try {
      const affectedSubsSnap = await db
        .collectionGroup("customer_subscriptions")
        .where("planId", "==", planId)
        .where("status", "in", ["active", "trialing"])
        .get();

      if (affectedSubsSnap.empty) {
        logger.info(`No active subscriptions found for plan: ${planId}`);
        return;
      }

      const storeIdsToUpdate = new Set();
      const batch = db.batch();

      affectedSubsSnap.docs.forEach((doc) => {
        const storeRef = doc.ref.parent.parent;
        if (storeRef) {
          storeIdsToUpdate.add(storeRef.id);
        }
        batch.update(doc.ref, {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          "metadata.lastPlanSyncAt": admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      const projectPromises = Array.from(storeIdsToUpdate).map((sId) =>
        projectStoreSubscriptionState(sId)
      );
      await Promise.allSettled(projectPromises);

      logger.info(`Successfully synchronized ${storeIdsToUpdate.size} stores for plan update.`);
    } catch (error) {
      logger.error("Failed to propagate subscription plan changes", {
        planId,
        error: String(error),
      });
    }
  }
);

exports.onStoreApproved = onDocumentUpdated(
  {
    document: "stores/{storeId}",
    region: "asia-south1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const storeId = event.params.storeId;

    if (before.status === "approved" || after.status !== "approved") {
      return;
    }

    logger.info(`Store approved: ${storeId}. Seeding subscription_state...`);

    try {
      const existingDoc = await db
        .collection("stores")
        .doc(storeId)
        .collection("subscription_state")
        .doc("current")
        .get();

      if (existingDoc.exists) return;

      const planDoc = await db
        .collection("platform_subscription_plans")
        .doc("monthly-starter")
        .get();

      if (!planDoc.exists) {
        throw new Error("Default subscription plan 'monthly-starter' not found");
      }

      const plan = planDoc.data();
      const now = new Date();
      const trialEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

      const entitlementData = {
        status: "trialing",
        planId: planDoc.id,
        planName: plan.name || "",
        billingCycle: plan.billingCycle || "monthly",
        priceMinor: plan.priceMinor || 0,
        currency: plan.currency || "INR",
        featureList: plan.featureList || [],
        limits: plan.limits || {},
        effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
        effectiveUntil: admin.firestore.Timestamp.fromDate(trialEnd),
        sourceSubscriptionId: "welcome-trial",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db
        .collection("stores")
        .doc(storeId)
        .collection("subscription_state")
        .doc("current")
        .set(entitlementData);

    } catch (error) {
      logger.error(`Error creating subscription_state for ${storeId}:`, error);
    }
  }
);

exports.expireSubscriptions = onSchedule(
  {
    schedule: "every 24 hours",
    region: "asia-south1",
    timeoutSeconds: 60,
  },
  async () => {
    logger.info("Running daily subscription expiry check...");
    const now = admin.firestore.Timestamp.now();

    const expiredSubsSnapshot = await db
      .collectionGroup("customer_subscriptions")
      .where("status", "in", ["active", "trialing"])
      .where("currentPeriodEnd", "<", now)
      .get();

    if (expiredSubsSnapshot.empty) {
      logger.info("No subscriptions to expire.");
      return;
    }

    const batch = db.batch();
    const storeIdsToReproject = new Set();

    expiredSubsSnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      const storeRef = doc.ref.parent.parent;
      if (storeRef) storeIdsToReproject.add(storeRef.id);
    });

    await batch.commit();

    const projectPromises = Array.from(storeIdsToReproject).map((id) =>
      projectStoreSubscriptionState(id)
    );
    await Promise.allSettled(projectPromises);
  }
);