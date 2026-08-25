/**
 * Geraetefreischaltung und passwortlose Anmeldung fuers Personal.
 *
 * Im Vereinsheim wechseln sich Kellner, Kueche und Bar an einem Tablet ab.
 * Jedes Mal eine E-Mail-Adresse und ein Passwort einzutippen, waehrend Gaeste
 * warten, ist nicht praktikabel - und fuehrt in der Praxis dazu, dass die
 * Zugangsdaten auf einem Zettel neben dem Geraet liegen.
 *
 * Deshalb: Ein Admin schaltet ein Geraet einmalig frei. Das Geraet erhaelt
 * dabei ein langes Zufallsgeheimnis, das nur lokal liegt; in der Datenbank
 * steht nur dessen Pruefsumme. Auf einem freigeschalteten Geraet genuegt
 * danach ein Tippen auf den Namen.
 *
 * Zwei Grenzen sind fest eingezogen:
 *   - Adminkonten erscheinen nie in der Liste und lassen sich hierueber nicht
 *     anmelden. Fuer sie bleibt es bei E-Mail und Passwort.
 *   - Ein Geraet laesst sich jederzeit widerrufen, etwa wenn das Tablet
 *     abhandenkommt. Danach zeigt es nur noch die Passwortmaske.
 */
const crypto = require('crypto');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

try { admin.app(); } catch (e) { admin.initializeApp(); }

const REGION = 'europe-west3';
const onCall = (handler) =>
  functions.region(REGION).runWith({ memory: '256MB', timeoutSeconds: 30 }).https.onCall(handler);

const hash = (s) => crypto.createHash('sha256').update(String(s)).digest('hex');

/** Vergleich ohne Laufzeitunterschied, damit sich das Geheimnis nicht erraten laesst. */
function gleich(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

/**
 * Prueft Geraetekennung und Geheimnis. Wirft, wenn das Geraet unbekannt,
 * widerrufen oder das Geheimnis falsch ist.
 */
async function pruefeGeraet(data) {
  const deviceId = (data && data.deviceId ? data.deviceId : '').toString();
  const secret = (data && data.secret ? data.secret : '').toString();
  if (!deviceId || !secret) {
    throw new functions.https.HttpsError('invalid-argument', 'Geraetekennung fehlt.');
  }
  const snap = await admin.firestore().collection('devices').doc(deviceId).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Dieses Gerät ist nicht freigeschaltet.');
  }
  const d = snap.data() || {};
  if (d.disabled === true) {
    throw new functions.https.HttpsError('permission-denied', 'Die Freischaltung dieses Geräts wurde widerrufen.');
  }
  if (!gleich(hash(secret), d.secretHash || '')) {
    throw new functions.https.HttpsError('permission-denied', 'Dieses Gerät ist nicht freigeschaltet.');
  }
  return { deviceId, data: d };
}

// ------------------------------------------------------------- Freischalten

/**
 * Schaltet das aufrufende Geraet frei. Nur fuer Admins.
 * Gibt Kennung und Geheimnis zurueck - das Geheimnis wird nirgends gespeichert
 * und kann nachtraeglich nicht erneut abgerufen werden.
 */
exports.registerDevice = onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Nur Administratoren können Geräte freischalten.');
  }
  const label = ((data && data.label) || '').toString().trim() || 'Unbenanntes Gerät';
  const secret = crypto.randomBytes(32).toString('base64url');
  const ref = admin.firestore().collection('devices').doc();

  await ref.set({
    label,
    secretHash: hash(secret),
    disabled: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: context.auth.uid,
  });

  return { deviceId: ref.id, secret, label };
});

/** Listet die freigeschalteten Geraete. Nur fuer Admins. */
exports.listDevices = onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Nur für Administratoren.');
  }
  const snap = await admin.firestore().collection('devices').orderBy('label').get();
  return {
    devices: snap.docs.map((d) => {
      const x = d.data() || {};
      return {
        id: d.id,
        label: x.label || '',
        disabled: x.disabled === true,
        lastUsed: x.lastUsed ? x.lastUsed.toDate().toISOString() : null,
        createdAt: x.createdAt ? x.createdAt.toDate().toISOString() : null,
      };
    }),
  };
});

/** Widerruft die Freischaltung eines Geraets. Nur fuer Admins. */
exports.revokeDevice = onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Nur für Administratoren.');
  }
  const deviceId = (data && data.deviceId ? data.deviceId : '').toString();
  if (!deviceId) throw new functions.https.HttpsError('invalid-argument', 'deviceId fehlt.');
  await admin.firestore().collection('devices').doc(deviceId).set(
    { disabled: true, revokedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  return { deviceId };
});

// ------------------------------------------------------ Personal am Geraet

/**
 * Liefert die auswaehlbaren Konten eines freigeschalteten Geraets.
 * Ohne Anmeldung aufrufbar - das Geraetegeheimnis ist der Nachweis.
 * Adminkonten und gesperrte Konten bleiben aussen vor.
 */
exports.staffList = onCall(async (data) => {
  await pruefeGeraet(data);

  const users = [];
  let token;
  do {
    const res = await admin.auth().listUsers(1000, token);
    for (const u of res.users) {
      const role = (u.customClaims && u.customClaims.role) || '';
      if (role === 'admin' || !role) continue; // Admin nie, rollenlos auch nicht
      if (u.disabled) continue;
      users.push({
        uid: u.uid,
        displayName: u.displayName || (u.email || '').split('@')[0],
        email: u.email || '',
        role,
      });
    }
    token = res.pageToken;
  } while (token);

  users.sort((a, b) => a.displayName.localeCompare(b.displayName, 'de'));
  return { users };
});

/**
 * Meldet ein Personalkonto auf einem freigeschalteten Geraet an.
 * Gibt einen Custom Token zurueck, den die App gegen eine Sitzung eintauscht.
 */
exports.staffSignIn = functions
    .region(REGION)
    // Ausdruecklich unter dem Firebase-Admin-Dienstkonto: das
    // Standard-Laufzeitkonto von Cloud Functions darf keine Custom Tokens
    // signieren ("iam.serviceAccounts.signBlob denied"), das Admin-SDK-Konto
    // dagegen schon. Betrifft nur diese Funktion - alle anderen kommen ohne
    // Signatur aus.
    .runWith({ memory: '256MB', timeoutSeconds: 30, serviceAccount: 'firebase-adminsdk-fbsvc@tsv-kassen-app.iam.gserviceaccount.com' })
    .https.onCall(async (data) => {
  const { deviceId } = await pruefeGeraet(data);

  const uid = (data && data.uid ? data.uid : '').toString();
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid fehlt.');

  let user;
  try {
    user = await admin.auth().getUser(uid);
  } catch (e) {
    throw new functions.https.HttpsError('not-found', 'Dieses Konto gibt es nicht.');
  }

  const role = (user.customClaims && user.customClaims.role) || '';
  if (role === 'admin') {
    // Doppelt gesichert: die Liste enthaelt Admins schon nicht, aber eine
    // Kennung liesse sich auch von Hand mitschicken.
    throw new functions.https.HttpsError(
      'permission-denied',
      'Administratoren melden sich mit E-Mail und Passwort an.'
    );
  }
  if (!role) {
    throw new functions.https.HttpsError('failed-precondition', 'Diesem Konto ist keine Rolle zugewiesen.');
  }
  if (user.disabled) {
    throw new functions.https.HttpsError('permission-denied', 'Dieses Konto ist gesperrt.');
  }

  await admin.firestore().collection('devices').doc(deviceId).set(
    { lastUsed: admin.firestore.FieldValue.serverTimestamp(), lastUser: uid },
    { merge: true }
  );

  const customToken = await admin.auth().createCustomToken(uid);
  return { token: customToken, uid, role };
});
