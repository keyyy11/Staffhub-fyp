require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');
const attendanceRoutes = require('./routes/attendance');
const authRoutes = require('./routes/auth');
const leaveRoutes = require('./routes/leave');
const profileRoutes = require('./routes/profile');
const adminRoutes = require('./routes/admin');
const supervisorRoutes = require('./routes/supervisor');
const staffRoutes = require('./routes/staff');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware — set CORS_ORIGIN in production (comma-separated: CMS + mobile origins)
const corsOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim()).filter(Boolean)
  : true;
app.use(cors({ origin: corsOrigins, credentials: true }));
// Medical leave uploads MC photo as base64 JSON — default 100kb is too small
app.use(express.json({ limit: '6mb' }));
app.use(express.urlencoded({ extended: true, limit: '6mb' }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/leave', leaveRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/staff', staffRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/supervisor', supervisorRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Staff Hub API is running' });
});

/** Tanpa auth — buka di browser / curl untuk pastikan app betul host & kod terkini. */
app.get('/api/capabilities', (req, res) => {
  res.json({
    success: true,
    data: {
      api: 'staffhub-api',
      adminStaffUpdatePut: true,
      adminStaffSupervisorPut: true,
      /** Set when auth routes accept empty staffId + autoStaffId (ADM/STF/SUP). */
      authOptionalStaffId: true,
    },
  });
});

// Root URL — supaya buka http://localhost:3000/ di browser nampak mesej, bukan "Cannot GET /"
app.get('/', (req, res) => {
  res.type('html').send(
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Staff Hub API</title></head><body style="font-family:sans-serif;padding:2rem;background:#0d1b2a;color:#42a5f5;">' +
      '<h1>Staff Hub API</h1><p>Server is running.</p>' +
      '<p><a href="/api/health" style="color:#90caf9;">Open /api/health (JSON)</a></p>' +
      '</body></html>'
  );
});

// Payload too large (e.g. MC image) — return JSON so mobile shows a clear message
app.use((err, req, res, next) => {
  if (err && (err.type === 'entity.too.large' || err.status === 413 || err.name === 'PayloadTooLargeError')) {
    return res.status(413).json({
      success: false,
      message: 'MC image is too large. Use a smaller photo or lower camera quality (max 5MB).',
    });
  }
  next(err);
});

// 404 JSON untuk /api/* — elak respons HTML (Flutter nampak "Non-JSON") & tunjuk laluan sebenar
app.use((req, res, next) => {
  if (req.method === 'OPTIONS') return next();
  if (req.originalUrl.startsWith('/api')) {
    return res.status(404).json({
      success: false,
      message: `No API route: ${req.method} ${req.originalUrl}`,
    });
  }
  next();
});

// Connect DB and start server
connectDB()
  .then(() => {
    const server = app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
      console.log('  GET  /api/capabilities — pastikan kod terkini (adminStaffUpdatePut: true)');
    });
    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`\n[ERROR] Port ${PORT} is already in use (another API instance is running).`);
        console.error('Fix: Close other terminals running "npm run dev", or kill the process:');
        console.error(`  Windows: netstat -ano | findstr :${PORT}`);
        console.error('  Then: taskkill /PID <number> /F\n');
      } else {
        console.error('Server error:', err);
      }
      process.exit(1);
    });
  })
  .catch((err) => {
    console.error('Failed to start server:', err.message || err);
    process.exit(1);
  });
