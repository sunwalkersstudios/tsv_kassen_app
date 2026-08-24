/*
 Backfill orgId on legacy documents for multi-tenant isolation.
 Usage:
   npm run backfill:org -- --orgId=YOUR_ORG_ID [--dryRun]

 Auth:
   This script uses the Firebase Admin SDK. Ensure GOOGLE_APPLICATION_CREDENTIALS is set
   to a service account JSON with Firestore Admin permissions, or run in an environment
   where Application Default Credentials are available.
*/

const admin = require('firebase-admin');

function parseArgs() {
  const args = process.argv.slice(2);
  const res = { orgId: null, dryRun: false };
  for (const a of args) {
    if (a.startsWith('--orgId=')) res.orgId = a.split('=')[1];
    if (a === '--dryRun') res.dryRun = true;
  }
  if (!res.orgId) {
    console.error('Missing required --orgId=YOUR_ORG_ID');
    process.exit(1);
  }
  return res;
}

async function initAdmin() {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error('Failed to initialize Firebase Admin SDK:', e);
    process.exit(1);
  }
  return admin.firestore();
}

async function backfillCollection(db, collName, orgId, { dryRun }) {
  console.log(`\n[${collName}] Backfilling orgId = ${orgId}${dryRun ? ' (dry-run)' : ''}`);
  const pageSize = 500;
  let lastDoc = null;
  let updated = 0;
  let scanned = 0;

  while (true) {
    let q = db.collection(collName).orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;
    let batch = db.batch();
    let batchCount = 0;
    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      if (!('orgId' in data) || data.orgId === null || data.orgId === '') {
        updated++;
        if (!dryRun) {
          batch.set(doc.ref, { orgId }, { merge: true });
          batchCount++;
          if (batchCount >= 400) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
    }
    if (!dryRun && batchCount > 0) {
      await batch.commit();
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }
  console.log(`[${collName}] Scanned: ${scanned}, Updated: ${updated}`);
}

async function backfillTicketItems(db, orgId, { dryRun }) {
  console.log(`\n[tickets.items] Backfilling orgId = ${orgId}${dryRun ? ' (dry-run)' : ''}`);
  const pageSize = 500;
  let lastDoc = null;
  let updated = 0;
  let scanned = 0;

  while (true) {
    let q = db.collectionGroup('items').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      if (!('orgId' in data) || data.orgId === null || data.orgId === '') {
        updated++;
        if (!dryRun) {
          batch.set(doc.ref, { orgId }, { merge: true });
          batchCount++;
          if (batchCount >= 400) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
    }

    if (!dryRun && batchCount > 0) {
      await batch.commit();
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }
  console.log(`[tickets.items] Scanned: ${scanned}, Updated: ${updated}`);
}

(async () => {
  const { orgId, dryRun } = parseArgs();
  const db = await initAdmin();

  const collections = ['users', 'menu', 'tables', 'events', 'tickets', 'sales'];
  for (const c of collections) {
    await backfillCollection(db, c, orgId, { dryRun });
  }
  await backfillTicketItems(db, orgId, { dryRun });

  console.log('\nBackfill complete.');
  process.exit(0);
})();
