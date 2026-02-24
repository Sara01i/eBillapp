const { auth } = require('../firebaseAdmin');

const verifyFirebaseToken = async (req, res, next) => {
  // DEV BYPASS (temporary): allow requests without token in development only
  if (process.env.NODE_ENV !== 'production' && req.query.dev_bypass === '1') {
    req.user = { uid: req.query.uid || 'DEV_UID' };
    console.warn('[auth] DEV BYPASS enabled. Using uid:', req.user.uid);
    return next();
  }

  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    console.warn('[auth] Missing or malformed Authorization header');
    return res.status(401).json({ ok: false, code: 'UNAUTHENTICATED', message: 'Missing token' });
  }

  const idToken = header.split('Bearer ')[1];
  console.log('[auth] Verifying Firebase ID token (first 12 chars):', `${idToken.slice(0, 12)}...`);

  try {
    const decodedToken = await auth.verifyIdToken(idToken);
    console.log('[auth] Token verified for uid:', decodedToken.uid);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('[auth] Failed to verify Firebase ID token:', error);
    res.status(401).json({ ok: false, code: 'UNAUTHENTICATED', message: 'Invalid token' });
  }
};

module.exports = verifyFirebaseToken;