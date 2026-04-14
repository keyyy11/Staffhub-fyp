require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');
const attendanceRoutes = require('./routes/attendance');
const authRoutes = require('./routes/auth');
const leaveRoutes = require('./routes/leave');
const profileRoutes = require('./routes/profile');
const adminRoutes = require('./routes/admin');
const staffRoutes = require('./routes/staff');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/leave', leaveRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/staff', staffRoutes);
app.use('/api/admin', adminRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Staff Hub API is running' });
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

// Connect DB and start server
connectDB()
  .then(() => {
    const server = app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
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
