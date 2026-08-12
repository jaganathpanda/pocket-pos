Here is a comprehensive README.md tailored for deploying and maintaining your Firebase Cloud Function.
Firebase Cloud Function: Store Registration Notifications
This repository contains a v2 Firebase Cloud Function (sendWelcomeEmailOnStoreRegistration) triggered whenever a new store registers in Firestore under the stores/{storeId} collection. It sends multi-channel welcome notifications (Email via Resend, SMS via Twilio, and WhatsApp via Twilio) based on dynamic feature flags and store settings configured in Firestore.
🛠 Prerequisites
Before deploying, ensure you have the following installed and set up:
Node.js: v18 or later.
Firebase CLI: Installed globally via npm install -g firebase-tools.
Firebase Project: A Firebase project with Firestore enabled.
Resend Account: API key generated for email delivery.
Twilio Account: Account SID and Auth Token generated for SMS and WhatsApp messaging.
🔒 Secret Manager Setup
This function relies on Firebase Secrets Manager (v2 parameters) to securely handle sensitive credentials.
Run the following Firebase CLI commands to define the secrets before deployment:



Bash
# 1. Resend API Key
firebase secrets:set RESEND_API_KEY

# 2. Twilio Account SID
firebase secrets:set TWILIO_ACCOUNT_SID

# 3. Twilio Auth Token
firebase secrets:set TWILIO_AUTH_TOKEN


(You will be prompted to paste the secret values securely into the terminal.)
⚙️ Firestore Configuration (platform_config)
Notification rules and channel credentials are controlled dynamically at runtime via a Firestore document.
Collection: platform_config
Document: notifications
Document Structure Example



JSON
{
  "email": {
    "enabled": true,
    "fromAddress": "Pocket POS <onboarding@updates.mypocketpos.in>",
    "apiKey": "" // Optional override. Leaves empty to fallback to RESEND_API_KEY secret
  },
  "sms": {
    "enabled": true,
    "fromNumber": "+12345678901",
    "accountSid": "", // Optional override. Leaves empty to fallback to TWILIO_ACCOUNT_SID secret
    "authToken": ""   // Optional override. Leaves empty to fallback to TWILIO_AUTH_TOKEN secret
  },
  "whatsapp": {
    "enabled": true,
    "fromNumber": "+12345678901", // Or "+14155238886" (Twilio sandbox number)
    "accountSid": "",
    "authToken": ""
  }
}


🚀 Deployment Instructions
1. Install Dependencies
Navigate to your functions folder and install the required NPM packages:



Bash
cd functions
npm install


2. Login to Firebase
Ensure you are authenticated with the correct Firebase account:



Bash
firebase login


3. Select Firebase Project
Set your target Firebase project:



Bash
firebase use <YOUR_PROJECT_ID>


4. Deploy the Function
Deploy the function targeting the region asia-south1:



Bash
firebase deploy --only functions:sendWelcomeEmailOnStoreRegistration


📊 Notification Logging & Debugging
Every notification event (sent, skipped, or failed) is automatically logged to the notification_logs collection in Firestore with a createdAt server timestamp.
Document Log Structure Example:



JSON
{
  "channel": "email",
  "template": "welcome_registration",
  "storeId": "STORE_12345",
  "to": "owner@example.com",
  "cc": ["info@mypocketpos.in"],
  "status": "sent", // Options: "sent", "failed", "skipped"
  "reason": "missing_owner_email", // Present when status is "skipped"
  "createdAt": "Timestamp"
}


Checking Cloud Logs
To view execution and failure logs in real time from your terminal:



Bash
firebase functions:log --only sendWelcomeEmailOnStoreRegistration


🏗 Function Architecture Overview
Trigger: Firestore document creation on stores/{storeId}.
Region: asia-south1
Timeout: 30s
Memory: 256MiB
Fail-Safe Design: Uses Promise.allSettled() to guarantee that external API delivery failures (or missing user fields) never throw unhandled rejections that break background execution.
