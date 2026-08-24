/**
 * Nutzerverwaltung fuer den Admin-Bereich.
 *
 * Die App ruft diese fuenf Funktionen seit jeher auf, sie existierten aber nie -
 * die Oberflaeche lief ins Leere. Solange das so war, blieb die Rollenvergabe
 * an der Notloesung haengen, die Rolle aus dem E-Mail-Praefix abzuleiten.
 *
 * Die Rolle liegt jetzt in den Custom Claims des Auth-Kontos. Anders als ein
 * Firestore-Dokument kann ein Nutzer seine Claims nicht selbst schreiben; nur
 * das Backend mit Admin-Rechten kann sie setzen. Das Firestore-Dokument unter
 * users/{uid} wird weiter gepflegt, dient aber nur noch der Anzeige.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

try { admin.app(); } catch (e) { admin.initializeApp(); }

const REGION = 'europe-west3';
const ROLES = ['admin', 'server', 'kitchen', 'bar'];

/** Wirft, wenn der Aufrufer kein Admin ist. */
function assertAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  if (context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Diese Aktion ist Administratoren vorbehalten.'
    );
  }
}

function assertRole(role) {
  if (!ROLES.includes(role)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Unbekannte Rolle "${role}". Erlaubt: ${ROLES.join(', ')}.`
    );
  }
}

/** Verhindert, dass ein Admin sich selbst aussperrt. */
function assertNotSelf(context, uid, was) {
  if (context.auth.uid === uid) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${was} am eigenen Konto ist nicht moeglich. Bitte von einem anderen Adminkonto aus vornehmen.`
    );
  }
}

/** Lesbares Zufallspasswort ohne leicht verwechselbare Zeichen. */
function generatePassword(length = 10) {
  const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i++) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

/** Sucht die naechste freie Adresse der Form rolle1@tsv.local. */
async function freeEmailForRole(role) {
  for (let i = 1; i <= 99; i++) {
    const candidate = `${role}${i}@tsv.local`;
    try {
      await admin.auth().getUserByEmail(candidate);
      // existiert bereits, naechste Nummer probieren
    } catch (e) {
      if (e.code === 'auth/user-not-found') return candidate;
      throw e;
    }
  }
  throw new functions.https.HttpsError(
    'resource-exhausted',
    `Keine freie Adresse fuer die Rolle "${role}" gefunden.`
  );
}

/** Schreibt Rolle und Stammdaten nach users/{uid}, damit die Liste sie zeigt. */
async function writeUserDoc(uid, fields) {
  await admin.firestore().collection('users').doc(uid).set(
    { uid, ...fields, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
}

const onCall = (handler) =>
  functions.region(REGION).runWith({ memory: '256MB', timeoutSeconds: 60 }).https.onCall(handler);

// ----------------------------------------------------------------- Auflisten

exports.adminListUsers = onCall(async (data, context) => {
  assertAdmin(context);
  const limit = Math.min(Math.max(parseInt((data && data.limit) || 200, 10) || 200, 1), 1000);

  const users = [];
  let pageToken;
  do {
    const res = await admin.auth().listUsers(Math.min(1000, limit - users.length), pageToken);
    for (const u of res.users) {
      users.push({
        uid: u.uid,
        email: u.email || '',
        displayName: u.displayName || '',
        // Claim ist die Wahrheit; das Firestore-Dokument nur Anzeige
        role: (u.customClaims && u.customClaims.role) || '',
        disabled: !!u.disabled,
        lastSignIn: u.metadata.lastSignInTime || null,
      });
      if (users.length >= limit) break;
    }
    pageToken = res.pageToken;
  } while (pageToken && users.length < limit);

  // Konten ohne Claim: Rolle aus dem Firestore-Dokument nachreichen, damit
  // Altbestaende in der Liste nicht rollenlos erscheinen.
  const ohneClaim = users.filter((u) => !u.role);
  if (ohneClaim.length) {
    const snaps = await admin.firestore().getAll(
      ...ohneClaim.map((u) => admin.firestore().collection('users').doc(u.uid))
    );
    snaps.forEach((snap, i) => {
      if (snap.exists) ohneClaim[i].role = (snap.data() || {}).role || 'server';
      else ohneClaim[i].role = 'server';
    });
  }

  return { users };
});

// ------------------------------------------------------------------- Anlegen

exports.adminCreateUser = onCall(async (data, context) => {
  assertAdmin(context);
  const role = ((data && data.role) || 'server').toString();
  assertRole(role);

  const displayName = data && data.displayName ? data.displayName.toString().trim() : '';
  const email = data && data.email
    ? data.email.toString().trim().toLowerCase()
    : await freeEmailForRole(role);

  const givenPassword = data && data.password ? data.password.toString() : '';
  if (givenPassword && givenPassword.length < 8) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Das Passwort muss mindestens 8 Zeichen haben.'
    );
  }
  const password = givenPassword || generatePassword();

  let user;
  try {
    user = await admin.auth().createUser({
      email,
      password,
      displayName: displayName || email.split('@')[0],
      emailVerified: false,
    });
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError(
        'already-exists',
        `Die Adresse ${email} ist bereits vergeben.`
      );
    }
    throw new functions.https.HttpsError('internal', e.message);
  }

  await admin.auth().setCustomUserClaims(user.uid, { role });
  await writeUserDoc(user.uid, {
    email,
    displayName: user.displayName || '',
    role,
    disabled: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    uid: user.uid,
    email,
    displayName: user.displayName || '',
    role,
    // Nur zurueckgeben, wenn wir es selbst erzeugt haben - ein vom Admin
    // gesetztes Passwort muss nicht noch einmal ueber die Leitung.
    tempPassword: givenPassword ? null : password,
  };
});

// -------------------------------------------------------------- Rolle setzen

exports.adminSetRole = onCall(async (data, context) => {
  assertAdmin(context);
  const uid = (data && data.uid ? data.uid : '').toString();
  const role = (data && data.role ? data.role : '').toString();
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid fehlt.');
  assertRole(role);
  assertNotSelf(context, uid, 'Ein Rollenwechsel');

  await admin.auth().setCustomUserClaims(uid, { role });
  await writeUserDoc(uid, { role });
  // Bestehende Anmeldungen weiterlaufen lassen waere heikel: der alte Token
  // traegt die alte Rolle bis zu einer Stunde weiter. Widerrufen erzwingt eine
  // neue Anmeldung und damit einen frischen Token.
  await admin.auth().revokeRefreshTokens(uid);
  return { uid, role };
});

// ----------------------------------------------------------- Passwort setzen

exports.adminSetPassword = onCall(async (data, context) => {
  assertAdmin(context);
  const uid = (data && data.uid ? data.uid : '').toString();
  const password = (data && data.password ? data.password : '').toString();
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid fehlt.');
  if (password.length < 8) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Das Passwort muss mindestens 8 Zeichen haben.'
    );
  }
  await admin.auth().updateUser(uid, { password });
  await admin.auth().revokeRefreshTokens(uid);
  return { uid };
});

// -------------------------------------------------------- Konto (de)aktivieren

exports.adminDisableUser = onCall(async (data, context) => {
  assertAdmin(context);
  const uid = (data && data.uid ? data.uid : '').toString();
  const disabled = !!(data && data.disabled);
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid fehlt.');
  if (disabled) assertNotSelf(context, uid, 'Ein Sperren');

  await admin.auth().updateUser(uid, { disabled });
  await writeUserDoc(uid, { disabled });
  if (disabled) await admin.auth().revokeRefreshTokens(uid);
  return { uid, disabled };
});
