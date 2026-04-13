const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const passwordReset = require('./password_reset_handlers');

initializeApp();
const db = getFirestore();

// --- Custom email OTP password reset (callable) ---
exports.sendPasswordResetOtp = passwordReset.sendPasswordResetOtp;
exports.verifyPasswordResetOtp = passwordReset.verifyPasswordResetOtp;
exports.resetPasswordWithToken = passwordReset.resetPasswordWithToken;

exports.onSessionCompleted = onDocumentUpdated(
  {
    document: 'sessions/{sessionId}',
    region: 'us-central1',
  },
  async (event) => {
    const beforeSnap = event.data.before;
    const afterSnap = event.data.after;
    if (!beforeSnap.exists || !afterSnap.exists) {
      return;
    }
    const before = beforeSnap.data();
    const after = afterSnap.data();
    if (before.status === 'completed' || after.status !== 'completed') {
      return;
    }

    const userId = after.userId;
    const dogId = after.dogId || '';
    const sessionId = event.params.sessionId;

    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    const userData = userSnap.data();
    const fcmToken = userData && userData.fcmToken;

    const notifRef = db.collection('notifications').doc();
    await notifRef.set({
      notificationId: notifRef.id,
      userId,
      title: 'Session complete',
      body: 'Your training session has been saved.',
      type: 'session_complete',
      isRead: false,
      data: {sessionId, dogId},
      createdAt: FieldValue.serverTimestamp(),
    });

    if (fcmToken && typeof fcmToken === 'string' && fcmToken.length > 0) {
      try {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: 'Session complete',
            body: 'Your training session has been saved.',
          },
          data: {
            type: 'session_complete',
            sessionId,
            dogId: String(dogId),
          },
        });
      } catch (e) {
        console.error('FCM send failed', e);
      }
    }
  },
);
