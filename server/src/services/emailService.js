const nodemailer = require('nodemailer');
require('dotenv').config();

console.log('[.env] GMAIL_EMAIL:', process.env.GMAIL_EMAIL);
console.log('[.env] GMAIL_APP_PASSWORD length:', (process.env.GMAIL_APP_PASSWORD || '').length);
console.log('[.env] CWD:', process.cwd());

const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.GMAIL_EMAIL,
        pass: process.env.GMAIL_APP_PASSWORD,
    },
});

const sendOtpEmail = async (toEmail, otp, expiryMinutes) => {
    const mailOptions = {
        from: `"${process.env.FROM_NAME}" <${process.env.GMAIL_EMAIL}>`,
        to: toEmail,
        subject: 'رمز التحقق الخاص بك',
        html: `
        <div style="font-family: Arial, sans-serif; background-color: #121212; color: #ffffff; padding: 20px; border-radius: 10px; max-width: 400px; margin: auto; border: 1px solid #2e7d32;">
            <h2 style="color: #4caf50; text-align: center;">eBill Wallet</h2>
            <p style="text-align: center; font-size: 16px;">رمز التحقق الخاص بك هو:</p>
            <div style="background-color: #1e1e1e; padding: 15px; text-align: center; border-radius: 5px; border: 1px dashed #4caf50; margin: 20px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #4caf50;">${otp}</span>
            </div>
            <p style="font-size: 12px; color: #aaaaaa; text-align: center;">هذا الرمز صالح لمدة ${expiryMinutes} دقائق.</p>
            <p style="font-size: 12px; color: #aaaaaa; text-align: center;">إذا لم تطلب هذا الرمز، يرجى تجاهل الرسالة.</p>
        </div>
        `
    };

    // eslint-disable-next-line no-console
    console.log('[emailService] Sending OTP email to:', toEmail);

    try {
        const info = await transporter.sendMail(mailOptions);
        // eslint-disable-next-line no-console
        console.log('[emailService] sendMail success. messageId:', info && info.messageId);
        return info;
    } catch (error) {
        // eslint-disable-next-line no-console
        console.error('[emailService] sendMail error:', error);
        throw error;
    }
};

module.exports = { sendOtpEmail };
