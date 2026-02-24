const { db, admin } = require('../firebaseAdmin');
const { generateSalt, hashOtp, safeCompare } = require('../utils/crypto');
const { sendOtpEmail } = require('./emailService');

const OTP_TTL_MS = 10 * 60 * 1000;
const COOLDOWN_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;

const sendOtp = async (uid, email) => {
    const otpRef = db.collection('email_otps').doc(uid);
    const now = Date.now();

    // eslint-disable-next-line no-console
    console.log('[otpService.sendOtp] Start. uid:', uid, 'email:', email, 'docPath:', otpRef.path);

    const doc = await otpRef.get();

    // eslint-disable-next-line no-console
    console.log('[otpService.sendOtp] Existing doc exists:', doc.exists);

    if (doc.exists) {
        const data = doc.data();
        if (data.lastSentAt && (now - data.lastSentAt.toMillis() < COOLDOWN_MS)) {
            // eslint-disable-next-line no-console
            console.warn('[otpService.sendOtp] Cooldown active for uid:', uid);
            throw { status: 403, code: 'FORBIDDEN', message: 'Wait for cooldown' };
        }
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const salt = generateSalt();
    const hash = hashOtp(otp, salt);

    // eslint-disable-next-line no-console
    console.log('[otpService.sendOtp] Writing OTP doc for uid:', uid);

    await otpRef.set({
        hash,
        salt,
        expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS),
        lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        attempts: 0,
    });

    // eslint-disable-next-line no-console
    console.log('[otpService.sendOtp] OTP doc written. Sending email to:', email);

    await sendOtpEmail(email, otp, 10);

    // eslint-disable-next-line no-console
    console.log('[otpService.sendOtp] Completed successfully for uid:', uid);

    return { ok: true };
};

const verifyOtp = async (uid, otp) => {
    const otpRef = db.collection('email_otps').doc(uid);

    // eslint-disable-next-line no-console
    console.log('[otpService.verifyOtp] Start. uid:', uid, 'docPath:', otpRef.path, 'otp length:', otp && otp.length);

    const doc = await otpRef.get();

    // eslint-disable-next-line no-console
    console.log('[otpService.verifyOtp] Snapshot exists:', doc.exists, 'id:', doc.id);

    if (!doc.exists) {
        // eslint-disable-next-line no-console
        console.warn('[otpService.verifyOtp] No OTP record found for uid:', uid);
        throw { status: 404, code: 'NOT_FOUND', message: 'No OTP record' };
    }

    const data = doc.data();
    if (Date.now() > data.expiresAt.toMillis()) {
        // eslint-disable-next-line no-console
        console.warn('[otpService.verifyOtp] OTP expired for uid:', uid);
        throw { status: 410, code: 'GONE', message: 'OTP expired' };
    }
    if (data.attempts >= MAX_ATTEMPTS) {
        // eslint-disable-next-line no-console
        console.warn('[otpService.verifyOtp] Max attempts reached for uid:', uid);
        throw { status: 429, code: 'TOO_MANY_REQUESTS', message: 'Max attempts reached' };
    }

    const isValid = safeCompare(data.hash, otp, data.salt);

    if (!isValid) {
        // eslint-disable-next-line no-console
        console.warn('[otpService.verifyOtp] Invalid OTP for uid:', uid);
        await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
        throw { status: 403, code: 'FORBIDDEN', message: 'Invalid OTP' };
    }

    const batch = db.batch();
    batch.delete(otpRef);
    batch.update(db.collection('users').doc(uid), {
        emailOtpVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // eslint-disable-next-line no-console
    console.log('[otpService.verifyOtp] Committing batch for uid:', uid);

    await batch.commit();

    // eslint-disable-next-line no-console
    console.log('[otpService.verifyOtp] Completed successfully for uid:', uid);

    return { ok: true };
};

module.exports = { sendOtp, verifyOtp };
