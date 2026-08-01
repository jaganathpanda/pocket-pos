"use strict";

/**
 * Pocket POS server-side notifications.
 *
 * A Firestore onCreate trigger on `stores/{storeId}` sends:
 *   1) a welcome + store-details email to the owner, and
 *   2) a heads-up email to the platform inbox (info@mypocketpos.in).
 *
 * The Resend API key lives ONLY here, as a Cloud Functions secret
 * (`firebase functions:secrets:set RESEND_API_KEY`). It is never shipped in the
 * app, so it can't be extracted from the APK or web bundle.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

// Verified Resend domain sender + platform inbox.
const FROM = "Pocket POS <info@mypocketpos.in>";
const ADMIN_EMAIL = "info@mypocketpos.in";

// IMPORTANT: this MUST match your Firestore database location, or deploy fails.
// Check it in Firebase Console → Firestore (shown near the top), or run
// `gcloud firestore databases list`. Common values: nam5, us-central1,
// asia-south1. Override without editing code via: functions .region as needed.
const REGION = "asia-south1";

async function sendEmail(apiKey, { to, subject, html, replyTo }) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM,
      to,
      subject,
      html,
      ...(replyTo ? { reply_to: replyTo } : {}),
    }),
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Resend HTTP ${res.status}: ${body}`);
  return body;
}

exports.onStoreCreated = onDocumentCreated(
  {
    document: "stores/{storeId}",
    region: REGION,
    secrets: [RESEND_API_KEY],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const d = snap.data() || {};

    const storeId = event.params.storeId;
    const storeName = d.name || storeId;
    const ownerName = d.ownerName || "";
    const username = d.ownerUsername || "";
    const ownerEmail = (d.email || "").trim();
    const ownerMobile = d.mobile || "";
    const apiKey = RESEND_API_KEY.value();

    // 1) Welcome + store details to the owner.
    if (ownerEmail) {
      try {
        await sendEmail(apiKey, {
          to: ownerEmail,
          subject: `Welcome to Pocket POS — your store "${storeName}" is set up`,
          html: welcomeHtml({ storeId, storeName, ownerName, username }),
          replyTo: ADMIN_EMAIL,
        });
        logger.info(`Welcome email sent to ${ownerEmail} for ${storeId}`);
      } catch (e) {
        logger.error(`Welcome email failed for ${storeId}: ${e}`);
      }
    } else {
      logger.warn(`Store ${storeId} has no owner email; skipping welcome mail.`);
    }

    // 2) Platform heads-up.
    try {
      await sendEmail(apiKey, {
        to: ADMIN_EMAIL,
        subject: `New store registered: ${storeName} (${storeId})`,
        html: adminHtml({
          storeId,
          storeName,
          ownerName,
          username,
          ownerEmail,
          ownerMobile,
        }),
      });
    } catch (e) {
      logger.error(`Admin email failed for ${storeId}: ${e}`);
    }
  }
);

function welcomeHtml({ storeId, storeName, ownerName, username }) {
  return `
<div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:auto;color:#0f1c1a">
  <div style="background:#005D4D;color:#fff;padding:20px 24px;border-radius:12px 12px 0 0">
    <h2 style="margin:0">Welcome to Pocket POS 🎉</h2>
  </div>
  <div style="border:1px solid #e4efec;border-top:0;padding:24px;border-radius:0 0 12px 12px">
    <p>Hi ${ownerName},</p>
    <p>Your store <strong>${storeName}</strong> has been created. Keep these details safe — you'll use them to log in:</p>
    <table style="border-collapse:collapse;margin:16px 0;font-size:15px">
      <tr><td style="padding:6px 12px;color:#5b6b68">Store ID</td><td style="padding:6px 12px;font-weight:700">${storeId}</td></tr>
      <tr><td style="padding:6px 12px;color:#5b6b68">Username</td><td style="padding:6px 12px;font-weight:700">${username}</td></tr>
    </table>
    <p>Your store is pending approval and will go live shortly. Once approved, sign in with your Store ID, username and password.</p>
    <p style="margin-top:20px">
      <a href="https://mypocketpos.in/?app=1" style="background:#005D4D;color:#fff;text-decoration:none;padding:10px 18px;border-radius:8px;font-weight:600">Open Pocket POS</a>
    </p>
    <p style="color:#5b6b68;font-size:13px;margin-top:20px">Need help? Reply to this email or write to ${ADMIN_EMAIL}.</p>
  </div>
</div>`;
}

function adminHtml({ storeId, storeName, ownerName, username, ownerEmail, ownerMobile }) {
  return `
<div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:auto;color:#0f1c1a">
  <h3>New store registered</h3>
  <table style="border-collapse:collapse;font-size:15px">
    <tr><td style="padding:6px 12px;color:#5b6b68">Store</td><td style="padding:6px 12px;font-weight:700">${storeName}</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Store ID</td><td style="padding:6px 12px">${storeId}</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Owner</td><td style="padding:6px 12px">${ownerName}</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Username</td><td style="padding:6px 12px">${username}</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Email</td><td style="padding:6px 12px">${ownerEmail || "-"}</td></tr>
    <tr><td style="padding:6px 12px;color:#5b6b68">Mobile</td><td style="padding:6px 12px">${ownerMobile || "-"}</td></tr>
  </table>
  <p style="color:#5b6b68;font-size:13px">Approve it from the platform admin screen.</p>
</div>`;
}
