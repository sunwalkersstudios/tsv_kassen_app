const functions = require('firebase-functions');
const admin = require('firebase-admin');

try { admin.app(); } catch (e) { admin.initializeApp(); }
const db = admin.firestore();

// Helper: find all device tokens for a waiter (serverId)
async function getUserDeviceTokens(uid) {
  if (!uid) return [];
  const doc = await db.collection('users').doc(uid).get();
  const data = doc.exists ? doc.data() : {};
  const tokens = (data && Array.isArray(data.deviceTokens)) ? data.deviceTokens : [];
  const last = data?.lastToken;
  const uniq = Array.from(new Set([...(tokens || []), ...(last ? [last] : [])]));
  return uniq.filter(t => typeof t === 'string' && t.length > 0);
}

// Helper: get human-readable table name
async function getTableName(tableId) {
  if (!tableId) return 'Unbekannt';
  const doc = await db.collection('tables').doc(tableId).get();
  if (!doc.exists) return 'Tisch ' + tableId;
  const name = doc.data()?.name;
  return name || ('Tisch ' + tableId);
}

// Trigger: when a ticket updates, send per-route ready notifications (kitchen/bar)
const notifyOnTicketReady = functions
  .runWith({ memory: '256MB', timeoutSeconds: 60, maxInstances: 10 })
  .region('europe-west3')
  .firestore
  .document('tickets/{ticketId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeRoutes = before.routesReady || {};
    const afterRoutes = after.routesReady || {};

    const kitchenBefore = !!beforeRoutes.kitchen;
    const kitchenAfter = !!afterRoutes.kitchen;
    const barBefore = !!beforeRoutes.bar;
    const barAfter = !!afterRoutes.bar;

    const events = [];
    if (!kitchenBefore && kitchenAfter) events.push('kitchen');
    if (!barBefore && barAfter) events.push('bar');

    if (!events.length) {
      console.log('[notifyOnTicketReady] No route transitioned to ready', {
        ticketId: context.params.ticketId,
        beforeRoutes,
        afterRoutes,
      });
      return null;
    }

    const serverId = after.serverId;
    const tableId = after.tableId;

    const [tokens, tableName] = await Promise.all([
      getUserDeviceTokens(serverId),
      getTableName(tableId),
    ]);

    if (!tokens.length) {
      console.warn('[notifyOnTicketReady] No device tokens for serverId', { serverId, ticketId: context.params.ticketId });
      return null;
    }

    try {
      for (const route of events) {
        const isKitchen = route === 'kitchen';
        const title = isKitchen ? 'Speisen fertig' : 'Getränke fertig';
        const body = `${isKitchen ? 'Speisen' : 'Getränke'} für ${tableName}: Abholen bitte.`;

        const payload = {
          notification: { title, body },
          android: {
            priority: 'high',
            notification: {
              channelId: 'ready_channel',
              priority: 'PRIORITY_HIGH',
            },
          },
          data: {
            type: 'route_ready',
            route,
            tableId: String(tableId || ''),
            ticketId: context.params.ticketId,
          },
        };

        console.log('[notifyOnTicketReady] Sending push', { route, serverId, ticketId: context.params.ticketId, tableName, tokenCount: tokens.length });
        const response = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
        console.log('[notifyOnTicketReady] Send result', { route, successCount: response.successCount, failureCount: response.failureCount });

        // Cleanup invalid tokens
        const invalid = [];
        response.responses.forEach((r, i) => {
          if (!r.success) {
            const code = (r.error && r.error.code) || '';
            if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token')) {
              invalid.push(tokens[i]);
            }
          }
        });
        if (invalid.length) {
          await db.collection('users').doc(serverId).set({
            deviceTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }
    } catch (err) {
      console.error('[notifyOnTicketReady] Error while sending notifications', { error: String(err), ticketId: context.params.ticketId, serverId });
    }

    return null;
  });

// Export under the expected deployed name
exports.notifyOnTicketReady = notifyOnTicketReady;
// Also export a backward-compatible alias (if an old name existed)
exports.onTicketReadyNotifyServer = notifyOnTicketReady;

// Scheduled daily Firestore export to GCS (requires Google Cloud project & permissions)
// Set env var EXPORT_BUCKET (e.g., gs://my-backup-bucket) and optionally EXPORT_PREFIX
const {google} = require('googleapis');
exports.scheduledFirestoreExport = functions
  .region('europe-west3')
  .pubsub.schedule('0 3 * * *') // daily at 03:00
  .timeZone('Europe/Berlin')
  .onRun(async (context) => {
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || (admin.app().options.projectId);
    const bucket = process.env.EXPORT_BUCKET;
    const prefix = process.env.EXPORT_PREFIX || 'firestore-backups';
    if (!bucket) {
      console.warn('[scheduledFirestoreExport] EXPORT_BUCKET not set, skipping');
      return null;
    }
    const path = `${bucket}/${prefix}/${new Date().toISOString().substring(0,10)}`;
    console.log('[scheduledFirestoreExport] Starting export', { projectId, path });
    try {
      const auth = await google.auth.getClient({ scopes: ['https://www.googleapis.com/auth/datastore'] });
      const firestore = google.firestore({ version: 'v1', auth });
      const name = `projects/${projectId}/databases/(default)`;
      await firestore.projects.databases.exportDocuments({
        name,
        requestBody: { outputUriPrefix: path },
      });
      console.log('[scheduledFirestoreExport] Export started', { name, path });
    } catch (err) {
      console.error('[scheduledFirestoreExport] Export failed', { error: String(err) });
    }
    return null;
  });
