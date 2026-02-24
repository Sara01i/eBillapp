const admin = require('firebase-admin');
const path = require('path');
require('dotenv').config();

const serviceAccountPath = path.resolve(
  process.env.GOOGLE_APPLICATION_CREDENTIALS || './serviceAccountKey.json',
);

// Load service account once so we can safely log non-sensitive metadata.
// Do NOT log private keys or emails.
// eslint-disable-next-line global-require, import/no-dynamic-require
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Safe startup logs: helps detect project mismatches between server and clients.
// These print only project identifiers, which are not secrets.
// eslint-disable-next-line no-console
console.log(
  '[firebaseAdmin] Initialized Firebase Admin with service account project_id:',
  serviceAccount.project_id,
);

// eslint-disable-next-line no-console
console.log(
  '[firebaseAdmin] admin.app().options.projectId =',
  admin.app().options.projectId,
);

const db = admin.firestore();
const auth = admin.auth();

module.exports = { admin, db, auth };
