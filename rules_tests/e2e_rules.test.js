import fs from 'fs';
import path from 'path';
import url from 'url';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';

const __filename = url.fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const projectId = 'demo-rules-test';

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8') },
  });

  await testEnv.clearFirestore();

  const orgId = `org_${Date.now()}`;
  const adminUid = `admin_${Date.now()}`;
  const otherUid = `user_${Date.now()}`;

  const adminCtx = testEnv.authenticatedContext(adminUid);
  const otherCtx = testEnv.authenticatedContext(otherUid);
  const adminDb = adminCtx.firestore();
  const otherDb = otherCtx.firestore();
  // Seed users with roles/orgs using disabled rules
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminSetup = context.firestore();
    await adminSetup.collection('users').doc(adminUid).set({ uid: adminUid, role: 'admin', orgId, email: 'a@b.c' });
    await adminSetup.collection('users').doc(otherUid).set({ uid: otherUid, role: 'server', orgId: 'other', email: 'o@x.c' });
  });

  // Admin can write menu for its org
  await assertSucceeds(
    adminDb.collection('menu').add({ name: 'Cola', price: 2.5, category: 'Getränke', route: 'bar', eventId: 'base', orgId })
  );
  // Other user (different org) cannot read admin's menu (even when filtering by that org)
  await assertFails(otherDb.collection('menu').where('orgId', '==', orgId).get());

  // Admin creates a ticket
  const ticketRef = await assertSucceeds(
    adminDb.collection('tickets').add({ tableId: 'T1', serverId: adminUid, status: 'open', orgId })
  ).then((ref) => ref);

  // Admin adds an item under the ticket
  await assertSucceeds(
    adminDb.collection('tickets').doc(ticketRef.id).collection('items').add({
      menuItemId: 'm1', qty: 1, route: 'bar', status: 'open', tableId: 'T1', orgId,
    })
  );

  // Admin creates a sale
  await assertSucceeds(
    adminDb.collection('sales').add({ ticketId: ticketRef.id, day: '2099-01-01', total: 2.5, paymentMethod: 'cash', orgId })
  );

  // Other org cannot read admin sales
  await assertFails(otherDb.collection('sales').where('orgId', '==', orgId).get());

  // Admin cannot operate on different org
  await assertFails(
    adminDb.collection('tables').add({ name: 'X', row: 0, col: 0, active: true, orgId: 'other' })
  );

  console.log('Rules E2E smoke test: PASS');
  await testEnv.cleanup();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
