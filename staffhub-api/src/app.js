const express = require('express');
const cors = require('cors');
const attendanceRoutes = require('./routes/attendance');
const authRoutes = require('./routes/auth');
const leaveRoutes = require('./routes/leave');
const profileRoutes = require('./routes/profile');
const adminRoutes = require('./routes/admin');
const supervisorRoutes = require('./routes/supervisor');
const staffRoutes = require('./routes/staff');

const app = express();

// Vercel serverless request body limit ~4.5MB on Hobby
const bodyLimit = process.env.VERCEL ? '4mb' : '6mb';

const corsOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim()).filter(Boolean)
  : true;
app.use(cors({ origin: corsOrigins, credentials: true }));
app.use(express.json({ limit: bodyLimit }));
app.use(express.urlencoded({ extended: true, limit: bodyLimit }));

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

app.get('/api/capabilities', (req, res) => {
  res.json({
    success: true,
    data: {
      api: 'staffhub-api',
      adminStaffUpdatePut: true,
      adminStaffSupervisorPut: true,
      authOptionalStaffId: true,
    },
  });
});

app.get('/', (req, res) => {
  res.type('html').send(
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Staff Hub API</title></head><body style="font-family:sans-serif;padding:2rem;background:#0d1b2a;color:#42a5f5;">' +
      '<h1>Staff Hub API</h1><p>Server is running.</p>' +
      '<p><a href="/api/health" style="color:#90caf9;">Open /api/health (JSON)</a></p>' +
      '</body></html>'
  );
});

app.use((err, req, res, next) => {
  if (err && (err.type === 'entity.too.large' || err.status === 413 || err.name === 'PayloadTooLargeError')) {
    return res.status(413).json({
      success: false,
      message: 'MC image is too large. Use a smaller photo or lower camera quality (max 4MB on cloud).',
    });
  }
  next(err);
});

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

module.exports = app;
