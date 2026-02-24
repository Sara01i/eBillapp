const express = require('express');
const router = express.Router();
const verifyFirebaseToken = require('../middlewares/auth');
const { sendOtp, verifyOtp } = require('../services/otpService');

router.post('/send', verifyFirebaseToken, async (req, res) => {
    try {
        const { email } = req.body;
        // eslint-disable-next-line no-console
        console.log('[emailOtpRoutes]/send hit. uid:', req.user && req.user.uid, 'email:', email);

        if (!email) return res.status(400).json({ ok: false, code: 'BAD_REQUEST', message: 'Email required' });

        // Ensure email matches token or allow any if user is logged in
        await sendOtp(req.user.uid, email);
        res.json({ ok: true, code: 'OK', message: 'OTP Sent' });
    } catch (error) {
        // eslint-disable-next-line no-console
        console.error('[emailOtpRoutes]/send error:', error);
        res.status(error.status || 500).json({
            ok: false,
            code: error.code || 'INTERNAL_ERROR',
            message: error.message,
            ...(error.details ? { details: error.details } : {}),
        });
    }
});

router.post('/verify', verifyFirebaseToken, async (req, res) => {
    try {
        const { code } = req.body;
        // eslint-disable-next-line no-console
        console.log('[emailOtpRoutes]/verify hit. uid:', req.user && req.user.uid, 'code:', code);

        if (!code || code.length !== 6) {
            return res.status(400).json({ ok: false, code: 'BAD_REQUEST', message: '6-digit code required' });
        }

        await verifyOtp(req.user.uid, code);
        res.json({ ok: true, code: 'OK', message: 'Verified' });
    } catch (error) {
        // eslint-disable-next-line no-console
        console.error('[emailOtpRoutes]/verify error:', error);
        res.status(error.status || 500).json({
            ok: false,
            code: error.code || 'INTERNAL_ERROR',
            message: error.message,
            ...(error.details ? { details: error.details } : {}),
        });
    }
});

module.exports = router;
