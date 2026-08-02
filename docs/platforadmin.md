There's no in-app admin registration — that's intentional. A platform admin is just a normal Firebase Auth user (real email + password) whose UID also has a doc in the platform_admins collection. adminLogin signs in, then checks platform_admins/{uid} exists; no doc → "This account is not a platform admin." The first admin must be bootstrapped in the Firebase console, because the rule allow write: if isPlatformAdmin() means only an existing admin could create another (chicken-and-egg).

Do this in your current project (mypocketpos — you just switched projects, so it must be set up there):

1. Enable Email/Password auth
Firebase Console → mypocketpos → Authentication → Sign-in method → enable Email/Password.

2. Create the admin user
Authentication → Users → Add user → enter an email (e.g. admin@mypocketpos.in or your own) + a password → copy the generated UID.

3. Make that user an admin (create the Firestore doc)
Firestore Database → create collection platform_admins → Document ID = the UID from step 2 → add any field (e.g. email: "admin@mypocketpos.in"). Only the doc's existence is checked, contents don't matter.
(Console writes bypass security rules, which is how the first admin gets created.)

4. Deploy the rules to mypocketpos
The platform_admins / approval rules were only deployed to the old project. Deploy to the new one, or the admin screen's reads fail:


firebase deploy --only firestore:rules --project mypocketpos
5. Log in as admin (in the app)
On the store login screen, tap "Platform admin login" at the bottom → /admin-login → enter the email + password from step 2. On success you land on /admin (the approvals screen) where you approve/suspend pending stores.

Notes
Admin uses a real email (unlike store logins, which use synthesized username@storeId.pocketpos.app).
To add more admins later: repeat steps 2–3 in the console (there's no UI for it). If you'd like, I can add a small "manage admins" screen so an existing admin can promote others from within the app.
On mobile, admin sign-in hits the same SHA-fingerprint/Play-Integrity requirement as store login — make sure the new com.mypocketpos.app app's SHA-1/256 are registered in mypocketpos, or sign-in can stall on a device (web is unaffected).