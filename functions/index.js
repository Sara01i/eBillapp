const crypto = require("crypto");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");
const logger = require("firebase-functions/logger");
const {defineSecret} = require("firebase-functions/params");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();

const db = admin.firestore();

const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");
const SENDGRID_FROM_EMAIL = defineSecret("SENDGRID_FROM_EMAIL");
const SENDGRID_FROM_NAME = defineSecret("SENDGRID_FROM_NAME");

const OTP_TTL_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 5;

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function generateOtpCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function generateSalt() {
  return crypto.randomBytes(16).toString("hex");
}

function hashOtp(code, salt) {
  return crypto.createHash("sha256").update(`${code}:${salt}`).digest("hex");
}

function toMillis(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (typeof value === "number") {
    return value;
  }
  return null;
}

function safeHexCompare(leftHex, rightHex) {
  try {
    const left = Buffer.from(String(leftHex || ""), "hex");
    const right = Buffer.from(String(rightHex || ""), "hex");
    if (left.length === 0 || right.length === 0 || left.length !== right.length) {
      return false;
    }
    return crypto.timingSafeEqual(left, right);
  } catch (_) {
    return false;
  }
}

async function ensureUserDocument(uid, email) {
  const userRef = db.collection("users").doc(uid);
  await userRef.set(
      {
        uid,
        email: email || "",
        emailOtpVerified: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
}

exports.sendEmailOtp = onCall(
    {
      region: "us-central1",
      secrets: [SENDGRID_API_KEY, SENDGRID_FROM_EMAIL, SENDGRID_FROM_NAME],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولًا.");
      }

      const authUid = request.auth.uid;
      const authEmail = normalizeEmail(request.auth.token.email);

      const requestedUid = String(request.data?.uid || "").trim();
      const requestedEmail = normalizeEmail(request.data?.email);

      if (requestedUid && requestedUid !== authUid) {
        throw new HttpsError("permission-denied", "بيانات المستخدم غير متطابقة.");
      }

      if (requestedEmail && authEmail && requestedEmail !== authEmail) {
        throw new HttpsError("permission-denied", "البريد الإلكتروني غير متطابق.");
      }

      const userRecord = await admin.auth().getUser(authUid);
      const resolvedEmail = requestedEmail || normalizeEmail(userRecord.email) || authEmail;
      if (!resolvedEmail) {
        throw new HttpsError("failed-precondition", "لا يوجد بريد إلكتروني صالح لإرسال الرمز.");
      }

      const otpRef = db.collection("email_otps").doc(authUid);
      const otpSnapshot = await otpRef.get();
      const nowMs = Date.now();

      if (otpSnapshot.exists) {
        const existing = otpSnapshot.data() || {};
        const lastSentAtMs = toMillis(existing.lastSentAt);
        if (lastSentAtMs) {
          const waitMs = (lastSentAtMs + RESEND_COOLDOWN_SECONDS * 1000) - nowMs;
          if (waitMs > 0) {
            const waitSeconds = Math.ceil(waitMs / 1000);
            throw new HttpsError(
                "failed-precondition",
                `يرجى الانتظار ${waitSeconds} ثانية قبل إعادة الإرسال.`,
            );
          }
        }
      }

      const otpCode = generateOtpCode();
      const salt = generateSalt();
      const hash = hashOtp(otpCode, salt);
      const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + OTP_TTL_MS);

      await otpRef.set(
          {
            hash,
            salt,
            expiresAt,
            attempts: 0,
            lastSentAt: admin.firestore.Timestamp.fromMillis(nowMs),
            used: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      await ensureUserDocument(authUid, resolvedEmail);

      const fromEmail = String(SENDGRID_FROM_EMAIL.value() || "").trim();
      const fromName = String(SENDGRID_FROM_NAME.value() || "eBill Wallet").trim();
      if (!fromEmail) {
        throw new HttpsError("failed-precondition", "لم يتم إعداد عنوان الإرسال للبريد.");
      }

      const supportContact = fromEmail;
      const expiryMinutes = Math.floor(OTP_TTL_MS / 60000);

      const textBody = [
        "مرحبًا،",
        "",
        `رمز التحقق لحسابك في eBill هو: ${otpCode}`,
        `هذا الرمز صالح لمدة ${expiryMinutes} دقائق.`,
        "",
        "تنبيه أمني: لا تشارك هذا الرمز مع أي شخص.",
        `الدعم: ${supportContact}`,
      ].join("\n");

      const htmlBody = `
        <div style="font-family:Arial,sans-serif;line-height:1.7;color:#1f2937">
          <p>مرحبًا،</p>
          <p>رمز التحقق لحسابك في <strong>eBill</strong> هو:</p>
          <p style="font-size:26px;font-weight:700;letter-spacing:4px">${otpCode}</p>
          <p>هذا الرمز صالح لمدة ${expiryMinutes} دقائق.</p>
          <p><strong>تنبيه أمني:</strong> لا تشارك هذا الرمز مع أي شخص.</p>
          <p>الدعم: ${supportContact}</p>
        </div>
      `;

      try {
        sgMail.setApiKey(SENDGRID_API_KEY.value());
        await sgMail.send({
          to: resolvedEmail,
          from: {
            email: fromEmail,
            name: fromName || "eBill Wallet",
          },
          subject: "رمز التحقق لحسابك في eBill",
          text: textBody,
          html: htmlBody,
        });
      } catch (error) {
        logger.error("sendEmailOtp provider error", {
          uid: authUid,
          error: error?.message || String(error),
        });
        throw new HttpsError("unavailable", "تعذر إرسال البريد الآن. حاول لاحقًا.");
      }

      return {
        sent: true,
        cooldownSeconds: RESEND_COOLDOWN_SECONDS,
        expiresInSeconds: Math.floor(OTP_TTL_MS / 1000),
      };
    },
);

exports.verifyEmailOtp = onCall(
    {
      region: "us-central1",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولًا.");
      }

      const authUid = request.auth.uid;
      const requestedUid = String(request.data?.uid || "").trim();
      const code = String(request.data?.code || "").trim();

      if (requestedUid && requestedUid !== authUid) {
        throw new HttpsError("permission-denied", "بيانات المستخدم غير متطابقة.");
      }

      if (!/^\d{6}$/.test(code)) {
        throw new HttpsError("invalid-argument", "رمز التحقق يجب أن يكون 6 أرقام.");
      }

      const otpRef = db.collection("email_otps").doc(authUid);
      const userRef = db.collection("users").doc(authUid);

      const otpSnapshot = await otpRef.get();
      if (!otpSnapshot.exists) {
        throw new HttpsError("failed-precondition", "لا يوجد رمز نشط. اطلب رمزًا جديدًا.");
      }

      const otpData = otpSnapshot.data() || {};
      const used = otpData.used === true;
      const attempts = Number(otpData.attempts || 0);
      const expiresAtMs = toMillis(otpData.expiresAt);
      const salt = String(otpData.salt || "");
      const storedHash = String(otpData.hash || "");

      if (used) {
        throw new HttpsError("failed-precondition", "تم استخدام هذا الرمز مسبقًا.");
      }

      if (attempts >= MAX_ATTEMPTS) {
        throw new HttpsError("resource-exhausted", "تم تجاوز الحد الأقصى للمحاولات.");
      }

      if (!expiresAtMs || Date.now() > expiresAtMs) {
        await otpRef.set(
            {
              used: true,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        throw new HttpsError("deadline-exceeded", "انتهت صلاحية الرمز. اطلب رمزًا جديدًا.");
      }

      const incomingHash = hashOtp(code, salt);
      const isValid = safeHexCompare(storedHash, incomingHash);

      if (!isValid) {
        const nextAttempts = attempts + 1;
        await otpRef.set(
            {
              attempts: nextAttempts,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        if (nextAttempts >= MAX_ATTEMPTS) {
          throw new HttpsError("resource-exhausted", "تم تجاوز الحد الأقصى للمحاولات.");
        }
        throw new HttpsError("permission-denied", "رمز التحقق غير صحيح.");
      }

      const batch = db.batch();
      batch.set(
          otpRef,
          {
            used: true,
            attempts: attempts + 1,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      batch.set(
          userRef,
          {
            emailOtpVerified: true,
            emailOtpVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      await batch.commit();

      return {verified: true};
    },
);
