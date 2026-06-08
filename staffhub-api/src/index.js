require('dotenv').config();
const app = require('./app');
const connectDB = require('./config/db');

const PORT = process.env.PORT || 3000;

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
