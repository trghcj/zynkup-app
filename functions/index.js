// firebase-functions v6 exports the v2 API at the root; this trigger uses the v1 API.
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotificationOnApproval = functions.firestore
  .document("events/{eventId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before.isApproved && after.isApproved) {

      const usersSnapshot = await admin.firestore()
        .collection("users")
        .get();

      const tokens = [];

      usersSnapshot.forEach(doc => {
        const token = doc.data().fcmToken;
        if (token) tokens.push(token);
      });

      if (tokens.length === 0) return;

      const payload = {
        notification: {
          title: "New Event Approved 🎉",
          body: after.title,
        },
        data: {
          eventId: context.params.eventId, // 🔥 KEY FIX
        },
      };

      // FCM accepts at most 500 tokens per multicast request.
      const sends = [];
      for (let i = 0; i < tokens.length; i += 500) {
        sends.push(admin.messaging().sendEachForMulticast({
          tokens: tokens.slice(i, i + 500),
          notification: payload.notification,
          data: payload.data,
        }));
      }
      return Promise.all(sends);
    }
  });