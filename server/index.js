require('dotenv').config();
require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const emailOtpRoutes = require('./src/routes/emailOtpRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Development-only request logging (no bodies, no secrets)
if (process.env.NODE_ENV !== 'production') {
  app.use((req, res, next) => {
    const startedAt = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - startedAt;
      // eslint-disable-next-line no-console
      console.log(
        `[http] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${duration}ms)`,
      );
    });
    next();
  });
}

// Health Check
app.get('/health', (req, res) => {
  res.json({ ok: true, message: "server up" });
});

// Routes
app.use('/v1/email-otp', emailOtpRoutes);

// Start Server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
