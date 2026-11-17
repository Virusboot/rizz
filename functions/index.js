// Cloud Functions that send push notifications for Rizz.
// Deploy with: firebase deploy --only functions

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Must be the same location as your Firestore database.
// Mumbai is asia-south1. Change this if you chose another location.
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

initializeApp();
const db = getFirestore();

const DEAD_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

function truncate(text, max) {
  const t = String(text || '');
  return t.length > max ? t.slice(0, max - 1) + '…' : t;
}

/** Sends a push to every device of a user. Never throws. */
async function send(uid, notification, data) {
  try {
    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || user.get('notify') === false) return;

    const snap = await db.collection(`users/${uid}/tokens`).get();
    const tokens = snap.docs.map((d) => d.id);
    if (tokens.length === 0) return;

    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification,
      data,
      android: { priority: 'high' },
    });

    // Remove tokens of devices that no longer exist.
    const dead = [];
    res.responses.forEach((r, i) => {
      if (!r.success && r.error && DEAD_TOKEN_CODES.includes(r.error.code)) {
        dead.push(tokens[i]);
      }
    });
    await Promise.all(
      dead.map((t) => db.doc(`users/${uid}/tokens/${t}`).delete())
    );
  } catch (e) {
    logger.error('send failed', { uid, error: String(e) });
  }
}

// Someone liked you. The name stays hidden, like in the app.
exports.onLikeCreated = onDocumentCreated('likes/{likeId}', async (event) => {
  const like = event.data && event.data.data();
  if (!like || !like.to || !like.from) return;

  // If it is mutual, a match is created and the match notification covers it.
  const back = await db.doc(`likes/${like.to}_${like.from}`).get();
  if (back.exists) return;

  const notification = like.spark
    ? { title: 'Someone sent you a Spark', body: 'Open Rizz to see who.' }
    : { title: 'Someone likes you', body: 'Open Likes You to see who.' };
  await send(like.to, notification, { type: 'like' });
});

// It's a match: tell both people.
exports.onMatchCreated = onDocumentCreated(
  'matches/{matchId}',
  async (event) => {
    const match = event.data && event.data.data();
    if (!match) return;
    const users = match.users || [];
    const info = match.info || {};

    await Promise.all(
      users.map((uid) => {
        const other = users.find((u) => u !== uid);
        const name = (info[other] && info[other].name) || 'Someone';
        return send(
          uid,
          { title: "It's a match!", body: `You and ${name} like each other.` },
          { type: 'match', matchId: event.params.matchId }
        );
      })
    );
  }
);

// A new chat message goes to the other person.
exports.onMessageCreated = onDocumentCreated(
  'matches/{matchId}/messages/{msgId}',
  async (event) => {
    const msg = event.data && event.data.data();
    if (!msg || !msg.sender) return;

    const match = await db.doc(`matches/${event.params.matchId}`).get();
    if (!match.exists) return;
    const users = match.get('users') || [];
    const to = users.find((u) => u !== msg.sender);
    if (!to) return;

    const info = match.get('info') || {};
    const name = (info[msg.sender] && info[msg.sender].name) || 'New message';
    await send(
      to,
      { title: name, body: truncate(msg.text, 120) },
      { type: 'message', matchId: event.params.matchId }
    );
  }
);
