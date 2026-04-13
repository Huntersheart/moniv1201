# Custom Email OTP Password Reset (Firebase + Flutter)

This guide matches the implementation in **this repo**: Cloud Functions (`functions/password_reset_handlers.js`), Firestore collections, and Flutter screens under `lib/ui/views/auth/`.

---

## 1. Overview

### Architecture

| Layer | Responsibility |
|--------|----------------|
| **Flutter app** | Collect email, OTP, new password; call **callable** HTTPS functions only. Never hashes OTPs or updates passwords directly. |
| **Cloud Functions** | Generate OTP, hash with **bcrypt**, store in Firestore, send email (**Nodemailer**), verify OTP, issue **reset token**, call **Admin SDK** `updateUser` to set password. |
| **Firestore** | Stores hashed OTP + metadata; stores short-lived reset session (token). **No client read/write** (rules deny all). |
| **Firebase Auth** | Email/password provider must be enabled; users must already exist for OTP to be sent (unknown emails get a generic success message). |

### Why Admin SDK stays on the backend

Updating another user’s password (or your own without being signed in) requires **privileged** Firebase APIs. The client SDK cannot safely do this for an unauthenticated reset flow. Only **firebase-admin** on a trusted server (Cloud Functions) should call `getAuth().updateUser(uid, { password })`.

---

## 2. Project structure (this repo)

```
slgnara_collar/
├── lib/
│   ├── data/remote/
│   │   ├── password_reset_cloud_service.dart   # httpsCallable wrappers
│   │   ├── firebase_service.dart
│   │   └── auth_service.dart
│   ├── ui/
│   │   ├── controllers/
│   │   │   ├── password_reset_otp_controller.dart  # GetX: OTP flow state
│   │   │   └── auth_controller.dart
│   │   └── views/auth/
│   │       ├── forgot_password_view.dart
│   │       ├── verify_code_view.dart
│   │       └── create_password_view.dart
│   └── app/bindings/auth_binding.dart
├── functions/
│   ├── index.js # exports session trigger + password reset callables
│   ├── password_reset_handlers.js  # sendOtp / verifyOtp / resetPassword logic
│   └── package.json
├── firebase.json
├── firestore.rules
└── PASSWORD_RESET_OTP_GUIDE.md     # this file
```

---

## 3. Firebase Console setup

1. **Create / select project**  
   [Firebase Console](https://console.firebase.google.com) → your project (e.g. `hunters-heart`).

2. **Authentication**  
   **Build → Authentication → Sign-in method** → enable **Email/Password**.

3. **Firestore**  
   **Build → Firestore Database** → create database (production mode is fine; we add rules below).

4. **Cloud Functions**  
   **Build → Functions** → upgrade to **Blaze (pay-as-you-go)** if prompted (required for Cloud Functions + external SMTP).

5. **Billing**  
   Spark (free) tier does **not** include outbound Cloud Functions to arbitrary SMTP in all cases; **Blaze** is required for production Functions with Nodemailer.

6. **App Check** (optional)  
   If you enforce App Check on Functions, register debug tokens for dev builds.

---

## 4. Local development setup

### Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### Node for Functions

This repo pins **Node 20** in `functions/package.json`. Use nvm:

```bash
cd functions
nvm use 20   # or install Node 20
npm install
```

### Link project

This repo includes **`.firebaserc`** with default project **`hunters-heart`**. If you use a different Firebase project:

```bash
cd .. # repo root
firebase use --add # pick project, or edit .firebaserc "default"
```

**Do not** run commands with the literal text `YOUR_PROJECT_ID` — that was only a placeholder in older docs.

### Emulator (optional)

```bash
firebase emulators:start --only functions,firestore
```

For callable + secrets locally, see [Firebase emulator docs](https://firebase.google.com/docs/functions/local-emulator).

---

## 5. Firestore schema

### Collection: `password_reset_otps`

Document ID: `SHA-256(lowercase(trim(email)))` (hex string).

Example document:

```json
{
  "email": "user@example.com",
  "uid": "firebaseAuthUidHere",
  "otpHash": "$2a$10$....",
  "expiresAt": { "_seconds": 1710000000, "_nanoseconds": 0 },
  "used": false,
  "verifyAttempts": 0,
  "lastSentAt": { "_seconds": 1710000000, "_nanoseconds": 0 },
  "rateHourStart": { "_seconds": 1710000000, "_nanoseconds": 0 },
  "sendCountHour": 1,
  "createdAt": { "_seconds": 1710000000, "_nanoseconds": 0 }
}
```

### Collection: `password_reset_sessions`

Document ID: **reset token** (64 hex chars).

Example document:

```json
{
  "email": "user@example.com",
  "uid": "firebaseAuthUidHere",
  "createdAt": { "_seconds": 1710000000, "_nanoseconds": 0 },
  "expiresAt": { "_seconds": 1710000100, "_nanoseconds": 0 },
  "used": false
}
```

### Security rules

In `firestore.rules` (already added in this repo):

```text
match /password_reset_otps/{docId} {
  allow read, write: if false;
}
match /password_reset_sessions/{docId} {
  allow read, write: if false;
}
```

Only the **Admin SDK** in Cloud Functions can read/write these paths.

---

## 6. Email (Nodemailer + Gmail)

### Gmail

1. Google Account → **Security** → **2-Step Verification** (on).
2. **App passwords** → create app password for “Mail”.
3. Use:
   - **SMTP_HOST**: `smtp.gmail.com`
   - **SMTP_PORT**: `465`
   - **SMTP_USER**: your Gmail address
   - **SMTP_PASS**: the 16-character app password (stored as a **secret**)
   - **SMTP_FROM**: same as user or your “from” name/address

### Store secrets safely

Do **not** commit passwords. Use Firebase **Secrets** for `SMTP_PASS`:

```bash
echo -n 'YOUR_APP_PASSWORD_HERE' | firebase functions:secrets:set SMTP_PASS
```

Non-secret strings use `defineString` in code (`SMTP_HOST`, `SMTP_USER`, `SMTP_FROM`, `SMTP_PORT`). Set them at deploy time when the CLI prompts, or configure in Google Cloud for your function’s environment (see Firebase “environment configuration” docs for your CLI version).

### Sample email body

- **Subject**: `Your password reset code`
- **Body**: 6-digit code, expiry time (10 minutes in code), “ignore if you didn’t request”.

---

## 7. Callable API (backend)

| Function name | Input | Output |
|---------------|--------|--------|
| `sendPasswordResetOtp` | `{ email }` | `{ ok, message }` |
| `verifyPasswordResetOtp` | `{ email, otp }` | `{ ok, resetToken, expiresInSeconds }` |
| `resetPasswordWithToken` | `{ email, resetToken, newPassword }` | `{ ok, message }` |

**Region**: `us-central1` (must match Flutter `PasswordResetCloudService.region`).

**Security behaviour**

- OTP: 6 digits, **bcrypt** hash, expiry **10 minutes**, max **5** verify attempts.
- Resend cooldown **60s**, max **5** sends per rolling hour per email (server-side).
- Reset session: **15 minutes**, single use; password min length **8** (Functions).

---

## 8. Flutter service & GetX

- **`PasswordResetCloudService`**: `sendOtp`, `verifyOtp`, `resetPassword`.
- **`PasswordResetOtpController`**: UI loading, email + `resetToken`, resend cooldown timer.
- **`AuthBinding`**: registers both + existing `AuthController`.

**Create password** screen supports:

- **OTP flow**: `resetToken` in memory after verify → `resetPasswordWithToken`.
- **Legacy email link**: `?oobCode=` still uses `AuthController.setNewPassword` + Firebase client `confirmPasswordReset`.

---

## 9. Deployment

```bash
# From repo root (default project is hunters-heart via .firebaserc)
firebase deploy --only firestore:rules
firebase deploy --only functions
# Or explicitly: firebase deploy --only functions --project hunters-heart
```

First deploy with **secrets**:

1. Create secret: `SMTP_PASS` (see above).
2. When CLI asks for `SMTP_HOST`, `SMTP_USER`, `SMTP_FROM`, enter production values.

Verify in **Firebase Console → Functions** that `sendPasswordResetOtp`, `verifyPasswordResetOtp`, `resetPasswordWithToken` appear.

---

## 10. Testing checklist

| Step | Action | Expected |
|------|--------|----------|
| 1 | Valid registered email → Send code | Email received, Firestore `password_reset_otps` doc created |
| 2 | Unregistered email | Same success message; **no** email (anti-enumeration) |
| 3 | Wrong OTP | Error; `verifyAttempts` increments |
| 4 | Expired OTP | Error after 10 min |
| 5 | Resend | Blocked &lt; 60s; allowed after cooldown |
| 6 | Valid OTP | Navigate to new password; `password_reset_sessions` doc created |
| 7 | New password ≥8 chars | Login with new password works |
| 8 | Reuse reset token | Second attempt fails (`used`) |

---

## 11. Common errors

| Issue | Fix |
|--------|-----|
| `SMTP is not configured` | Set `SMTP_HOST`, `SMTP_USER`, `SMTP_FROM`, secret `SMTP_PASS`. |
| `PERMISSION_DENIED` on Firestore from app | Normal if you tried to read OTP docs from client; only Functions should access. |
| Callable `NOT_FOUND` | Wrong function name or region; use `us-central1` in Flutter. |
| `SMTP_PASS` missing on deploy | Run `firebase functions:secrets:set SMTP_PASS` and redeploy. |
| Gmail blocks sign-in | Use **App Password**, not normal password. |
| Admin `updateUser` weak password | Firebase Auth password policy; use longer / mixed password. |

---

## 12. Security best practices (summary)

- Never store **plain** OTP in Firestore; only **bcrypt** hash.
- Limit attempts and resends; expire OTP and reset sessions quickly.
- Keep **reset token** only in memory on the client until password submit (we don’t persist it in SharedPreferences).
- Rate-limit by email on the server (implemented).
- Do not expose whether an email is registered from the `sendOtp` response (generic message).

---

## 13. Commands cheat sheet

```bash
firebase login
cd functions && npm install && cd ..
# Use your real Gmail App Password (16 chars), not the word YOUR_GMAIL_APP_PASSWORD
echo -n 'xxxxxxxxxxxxxxxx' | firebase functions:secrets:set SMTP_PASS
firebase deploy --only firestore:rules
firebase deploy --only functions
```

If the CLI says **no active project**, ensure **`.firebaserc`** exists in the repo root (this project sets `default` to `hunters-heart`) or add `--project hunters-heart` to every command.

Flutter:

```bash
flutter pub get
flutter run
```

---

*Generated for the Signara Collar / Hunter Hearts codebase. Adjust project IDs and regions to match your Firebase project.*
