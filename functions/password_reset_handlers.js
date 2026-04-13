/**
 * Custom email OTP password reset — callable HTTPS functions.
 * OTP is hashed (bcrypt) in Firestore; plain OTP exists only in the email body.
 * Password changes use Firebase Admin SDK only (never from the client).
 */
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineString, defineSecret} = require('firebase-functions/params');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

// --- Config (set via `firebase functions:config` legacy OR params — see DEPLOY.md) ---
const smtpHost = defineString('SMTP_HOST', {default: ''});
const smtpPort = defineString('SMTP_PORT', {default: '465'});
const smtpUser = defineString('SMTP_USER', {default: ''});
const smtpFrom = defineString('SMTP_FROM', {default: ''});
/** Set with: echo "your-app-password" | firebase functions:secrets:set SMTP_PASS */
const smtpPass = defineSecret('SMTP_PASS');

const REGION = 'us-central1';
const OTP_TTL_MIN = 10;
const SESSION_TTL_MIN = 15;
const MAX_VERIFY_ATTEMPTS = 5;
const RESEND_COOLDOWN_SEC = 60;
const MAX_OTP_SENDS_PER_HOUR = 5;
const MIN_PASSWORD_LEN = 8;

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

/** Firestore doc id — avoids storing raw email in document path. */
function emailDocId(email) {
  return crypto.createHash('sha256').update(normalizeEmail(email)).digest('hex');
}

function buildTransporter() {
  const host = smtpHost.value();
  const port = parseInt(smtpPort.value(), 10) || 465;
  const auth = {
    user: smtpUser.value(),
    pass: smtpPass.value(),
  };
  // Port 587: STARTTLS (common for Gmail / many hosts). 465: SSL.
  if (port === 587) {
    return nodemailer.createTransport({
      host,
      port: 587,
      secure: false,
      requireTLS: true,
      auth,
    });
  }
  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth,
  });
}

async function sendOtpEmail(toEmail, otp) {
  const host = smtpHost.value();
  const user = smtpUser.value();
  if (!host || !user) {
    throw new HttpsError(
      'failed-precondition',
      'SMTP is not configured. Set SMTP_HOST, SMTP_USER, and secret SMTP_PASS.',
    );
  }
  const from = smtpFrom.value() || user;
  const transporter = buildTransporter();
  const subject = 'Your password reset code';
  const text =
    `Your verification code is: ${otp}\n\n` +
    `It expires in ${OTP_TTL_MIN} minutes.\n` +
    `If you did not request a password reset, ignore this email.`;
  const html =
    `<p>Your verification code is:</p>` +
    `<p><strong style="font-size:24px;letter-spacing:4px">${otp}</strong></p>` +
    `<p>It expires in ${OTP_TTL_MIN} minutes.</p>` +
    `<p>If you did not request a password reset, ignore this email.</p>`;
  await transporter.sendMail({from, to: toEmail, subject, text, html});
}

/**
 * Step 1: Generate 6-digit OTP, hash with bcrypt, store in password_reset_otps, send email.
 * Returns sent:false if Auth has no user for this email (so the app can show a clear message).
 */
const sendPasswordResetOtp = onCall(
  {
    region: REGION,
    secrets: [smtpPass],
    enforceAppCheck: false,
    timeoutSeconds: 120,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'A valid email is required.');
    }

    let userRecord;
    try {
      userRecord = await getAuth().getUserByEmail(email);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        return {
          ok: true,
          sent: false,
          message:
            'No account for this email. Sign up first, or use the same email you use to log in.',
        };
      }
      console.error('getUserByEmail', e);
      throw new HttpsError('internal', 'Unable to process request.');
    }

    const db = getFirestore();
    const ref = db.collection('password_reset_otps').doc(emailDocId(email));
    const now = Date.now();
    const snap = await ref.get();

    let sendCountHour = 1;
    let hourStartMs = now;
    if (snap.exists) {
      const d = snap.data();
      const lastSent = d.lastSentAt?.toMillis?.() || 0;
      if (now - lastSent < RESEND_COOLDOWN_SEC * 1000) {
        const waitSec = Math.ceil(
          (RESEND_COOLDOWN_SEC * 1000 - (now - lastSent)) / 1000,
        );
        throw new HttpsError(
          'resource-exhausted',
          `Please wait ${waitSec} seconds before requesting another code.`,
        );
      }
      const prevHourStart = d.rateHourStart?.toMillis?.() || now;
      if (now - prevHourStart < 3600000) {
        sendCountHour = (d.sendCountHour || 0) + 1;
        hourStartMs = prevHourStart;
        if (sendCountHour > MAX_OTP_SENDS_PER_HOUR) {
          throw new HttpsError(
            'resource-exhausted',
            'Too many codes requested. Try again in about an hour.',
          );
        }
      }
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = Timestamp.fromMillis(now + OTP_TTL_MIN * 60 * 1000);

    await ref.set({
      email,
      uid: userRecord.uid,
      otpHash,
      expiresAt,
      used: false,
      verifyAttempts: 0,
      lastSentAt: FieldValue.serverTimestamp(),
      rateHourStart: Timestamp.fromMillis(hourStartMs),
      sendCountHour,
      createdAt: FieldValue.serverTimestamp(),
    });

    try {
      await sendOtpEmail(email, otp);
    } catch (err) {
      console.error('sendOtpEmail', err && err.message ? err.message : err);
      await ref.delete().catch(() => {});
      const hint =
        'Could not send email. Check Cloud Function SMTP params (SMTP_HOST, SMTP_USER, SMTP_PORT 465 or 587, secret SMTP_PASS) and Gmail App Password.';
      throw new HttpsError('internal', hint);
    }

    return {
      ok: true,
      sent: true,
      message: 'Check your inbox for the 6-digit code (and spam folder).',
    };
  },
);

/**
 * Step 2: Verify OTP; create short-lived reset session token in password_reset_sessions.
 */
const verifyPasswordResetOtp = onCall(
  {
    region: REGION,
    enforceAppCheck: false,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const otp = String(request.data?.otp || '')
      .replace(/\D/g, '')
      .slice(0, 6);
    if (!email || otp.length !== 6) {
      throw new HttpsError(
        'invalid-argument',
        'Email and a 6-digit code are required.',
      );
    }

    const db = getFirestore();
    const ref = db.collection('password_reset_otps').doc(emailDocId(email));
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError(
        'not-found',
        'No active code for this email. Request a new one.',
      );
    }

    const d = snap.data();
    if (d.used) {
      throw new HttpsError(
        'failed-precondition',
        'This code was already used. Request a new one.',
      );
    }
    if (d.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError(
        'failed-precondition',
        'This code has expired. Request a new one.',
      );
    }
    if ((d.verifyAttempts || 0) >= MAX_VERIFY_ATTEMPTS) {
      throw new HttpsError(
        'permission-denied',
        'Too many failed attempts. Request a new code.',
      );
    }

    const match = await bcrypt.compare(otp, d.otpHash);
    if (!match) {
      await ref.update({verifyAttempts: FieldValue.increment(1)});
      throw new HttpsError('permission-denied', 'Invalid code.');
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const sessionExpires = Timestamp.fromMillis(
      Date.now() + SESSION_TTL_MIN * 60 * 1000,
    );

    const batch = db.batch();
    batch.set(db.collection('password_reset_sessions').doc(resetToken), {
      email,
      uid: d.uid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: sessionExpires,
      used: false,
    });
    batch.update(ref, {
      used: true,
      verifiedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {
      ok: true,
      resetToken,
      expiresInSeconds: SESSION_TTL_MIN * 60,
    };
  },
);

/**
 * Step 3: Validate reset session and set password with Admin SDK.
 */
const resetPasswordWithToken = onCall(
  {
    region: REGION,
    enforceAppCheck: false,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const resetToken = String(request.data?.resetToken || '').trim();
    const newPassword = String(request.data?.newPassword || '');
    if (!email || !resetToken) {
      throw new HttpsError(
        'invalid-argument',
        'Email and reset token are required.',
      );
    }
    if (newPassword.length < MIN_PASSWORD_LEN) {
      throw new HttpsError(
        'invalid-argument',
        `Password must be at least ${MIN_PASSWORD_LEN} characters.`,
      );
    }

    const db = getFirestore();
    const ref = db.collection('password_reset_sessions').doc(resetToken);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError(
        'not-found',
        'Invalid or expired reset session. Start again from “Forgot password”.',
      );
    }

    const d = snap.data();
    if (d.used) {
      throw new HttpsError(
        'failed-precondition',
        'This reset link was already used.',
      );
    }
    if (d.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError(
        'failed-precondition',
        'Reset session expired. Request a new code.',
      );
    }
    if (normalizeEmail(d.email) !== email) {
      throw new HttpsError('permission-denied', 'Email does not match this session.');
    }

    try {
      await getAuth().updateUser(d.uid, {password: newPassword});
    } catch (e) {
      console.error('updateUser password', e);
      if (e.code === 'auth/weak-password') {
        throw new HttpsError('invalid-argument', 'Password is too weak for Firebase Auth.');
      }
      throw new HttpsError('internal', 'Could not update password.');
    }

    await ref.update({
      used: true,
      consumedAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, message: 'Password updated. You can sign in now.'};
  },
);

module.exports = {
  sendPasswordResetOtp,
  verifyPasswordResetOtp,
  resetPasswordWithToken,
};
