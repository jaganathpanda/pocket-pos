const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { Resend } = require("resend");

admin.initializeApp();

const db = admin.firestore();
const resendApiKey = defineSecret("RESEND_API_KEY");
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");

const INFO_EMAIL = "info@mypocketpos.in";

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
  const accountSid =
    typeof channel.accountSid === "string" && channel.accountSid.trim().length > 0
      ? channel.accountSid.trim()
      : null;
  const authToken =
    typeof channel.authToken === "string" && channel.authToken.trim().length > 0
      ? channel.authToken.trim()
      : null;

  return {
    enabled: channel.enabled === true,
    fromAddress,
    fromNumber,
    apiKey,
    accountSid,
    authToken,
  };
}

function readEmailFeatureFlags(map) {
  return parseChannelConfig(map, "email");
}

function readSmsFeatureFlags(map) {
  return parseChannelConfig(map, "sms");
}

function readWhatsappFeatureFlags(map) {
  return parseChannelConfig(map, "whatsapp");
}

function normalizePhone(value) {
  if (typeof value !== "string") return null;
  const raw = value.trim();
  if (!raw) return null;

  const cleaned = raw.replace(/[\s\-()]/g, "");
  if (/^\+[1-9]\d{7,14}$/.test(cleaned)) return cleaned;

  const digits = cleaned.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 11 && digits.startsWith("0")) return `+91${digits.slice(1)}`;
  return null;
}

async function appendNotificationLog(entry) {
  await db.collection("notification_logs").add({
    ...entry,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendViaTwilio({ from, to, body, accountSid, authToken }) {

  const endpoint =
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const auth = Buffer.from(`${accountSid}:${authToken}`).toString("base64");

  const params = new URLSearchParams();
  params.set("From", from);
  params.set("To", to);
  params.set("Body", body);

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Twilio send failed (${resp.status}): ${text}`);
  }
}

function readSecretValue(secretParam) {
  try {
    const value = secretParam.value();
    return typeof value === "string" && value.trim().length > 0
      ? value.trim()
      : null;
  } catch (_) {
    return null;
  }
}

exports.sendWelcomeEmailOnStoreRegistration = onDocumentCreated(
  {
    document: "stores/{storeId}",
    region: "asia-south1",
    secrets: [resendApiKey, twilioAccountSid, twilioAuthToken],
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
    const normalizedMobile = normalizePhone(
      typeof store.mobile === "string" ? store.mobile : ""
    );

    let config;
    try {
      const cfgSnap = await db.collection("platform_config").doc("notifications").get();
      config = cfgSnap.data();
    } catch (err) {
      // Fail-safe: config read issues must not break registration flow.
      logger.error("Failed to read notification config; treating as disabled.", {
        storeId,
        error: String(err),
      });
      return;
    }

    const emailCfg = readEmailFeatureFlags(config);
    const smsCfg = readSmsFeatureFlags(config);
    const whatsappCfg = readWhatsappFeatureFlags(config);

    const defaultResendApiKey = readSecretValue(resendApiKey);
    const defaultTwilioAccountSid = readSecretValue(twilioAccountSid);
    const defaultTwilioAuthToken = readSecretValue(twilioAuthToken);

    const storeName =
      typeof store.name === "string" && store.name.trim().length > 0
        ? store.name.trim()
        : storeId;
    const ownerName =
      typeof store.ownerName === "string" && store.ownerName.trim().length > 0
        ? store.ownerName.trim()
        : "Store Owner";
    const ownerUsername =
      typeof store.ownerUsername === "string" && store.ownerUsername.trim().length > 0
        ? store.ownerUsername.trim()
        : "";

    const fromAddress =
      emailCfg.fromAddress || "Pocket POS <onboarding@updates.mypocketpos.in>";

    const emailSubject = `Welcome to Pocket POS - ${storeId}`;
    const plainBody = [
      `Hi ${ownerName},`,
      "",
      `Welcome to Pocket POS for \"${storeName}\".`,
      `Your Store ID is: ${storeId}`,
      "",
      "Your store is currently pending platform approval.",
      "Once approved, you can log in and start billing.",
      "",
      "Regards,",
      "Pocket POS Team",
    ].join("\n");

    const smsBody = `Welcome to Pocket POS, ${ownerName}. Your Store ID is ${storeId}. ` +
      "Your store is pending approval. We will notify you once approved.";

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

    if (smsCfg.enabled) {
      if (!normalizedMobile) {
        tasks.push(
          appendNotificationLog({
            channel: "sms",
            template: "welcome_registration",
            storeId,
            status: "skipped",
            reason: "missing_or_invalid_mobile",
          })
        );
      } else if (!smsCfg.fromNumber) {
        tasks.push(
          appendNotificationLog({
            channel: "sms",
            template: "welcome_registration",
            storeId,
            to: normalizedMobile,
            status: "skipped",
            reason: "missing_sms_from_number",
          })
        );
      } else {
        tasks.push((async () => {
          try {
            const accountSid = smsCfg.accountSid || defaultTwilioAccountSid;
            const authToken = smsCfg.authToken || defaultTwilioAuthToken;
            if (!accountSid || !authToken) {
              throw new Error("Missing Twilio credentials for SMS channel.");
            }
            await sendViaTwilio({
              from: smsCfg.fromNumber,
              to: normalizedMobile,
              body: smsBody,
              accountSid,
              authToken,
            });

            await appendNotificationLog({
              channel: "sms",
              template: "welcome_registration",
              storeId,
              to: normalizedMobile,
              status: "sent",
            });
          } catch (err) {
            logger.error("Welcome SMS send failed.", {
              storeId,
              to: normalizedMobile,
              error: String(err),
            });

            await appendNotificationLog({
              channel: "sms",
              template: "welcome_registration",
              storeId,
              to: normalizedMobile,
              status: "failed",
              error: String(err),
            });
          }
        })());
      }
    } else {
      tasks.push(
        appendNotificationLog({
          channel: "sms",
          template: "welcome_registration",
          storeId,
          status: "skipped",
          reason: "feature_disabled",
        })
      );
    }

    if (whatsappCfg.enabled) {
      if (!normalizedMobile) {
        tasks.push(
          appendNotificationLog({
            channel: "whatsapp",
            template: "welcome_registration",
            storeId,
            status: "skipped",
            reason: "missing_or_invalid_mobile",
          })
        );
      } else if (!whatsappCfg.fromNumber) {
        tasks.push(
          appendNotificationLog({
            channel: "whatsapp",
            template: "welcome_registration",
            storeId,
            to: normalizedMobile,
            status: "skipped",
            reason: "missing_whatsapp_from_number",
          })
        );
      } else {
        tasks.push((async () => {
          const whatsappTo = normalizedMobile.startsWith("whatsapp:")
            ? normalizedMobile
            : `whatsapp:${normalizedMobile}`;
          const whatsappFrom = whatsappCfg.fromNumber.startsWith("whatsapp:")
            ? whatsappCfg.fromNumber
            : `whatsapp:${whatsappCfg.fromNumber}`;
          try {
            const accountSid = whatsappCfg.accountSid || defaultTwilioAccountSid;
            const authToken = whatsappCfg.authToken || defaultTwilioAuthToken;
            if (!accountSid || !authToken) {
              throw new Error("Missing Twilio credentials for WhatsApp channel.");
            }
            await sendViaTwilio({
              from: whatsappFrom,
              to: whatsappTo,
              body: smsBody,
              accountSid,
              authToken,
            });

            await appendNotificationLog({
              channel: "whatsapp",
              template: "welcome_registration",
              storeId,
              to: whatsappTo,
              status: "sent",
            });
          } catch (err) {
            logger.error("Welcome WhatsApp send failed.", {
              storeId,
              to: whatsappTo,
              error: String(err),
            });

            await appendNotificationLog({
              channel: "whatsapp",
              template: "welcome_registration",
              storeId,
              to: whatsappTo,
              status: "failed",
              error: String(err),
            });
          }
        })());
      }
    } else {
      tasks.push(
        appendNotificationLog({
          channel: "whatsapp",
          template: "welcome_registration",
          storeId,
          status: "skipped",
          reason: "feature_disabled",
        })
      );
    }

    // Fail-safe: notification pipeline is best effort. Never throw from trigger.
    await Promise.allSettled(tasks);
  }
);
