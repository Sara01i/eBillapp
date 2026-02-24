const crypto = require('crypto');

const generateSalt = () => crypto.randomBytes(16).toString('hex');

const hashOtp = (otp, salt) => {
    return crypto.createHash('sha256').update(`${otp}:${salt}`).digest('hex');
};

const safeCompare = (storedHash, incomingOtp, salt) => {
    const incomingHash = hashOtp(incomingOtp, salt);
    // crypto.timingSafeEqual requires buffers of the same length
    const buf1 = Buffer.from(storedHash, 'hex');
    const buf2 = Buffer.from(incomingHash, 'hex');
    if (buf1.length !== buf2.length) return false;
    return crypto.timingSafeEqual(buf1, buf2);
};

module.exports = { generateSalt, hashOtp, safeCompare };
