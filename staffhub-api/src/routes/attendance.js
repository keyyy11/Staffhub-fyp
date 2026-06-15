const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
router.post('/clock-in', attendanceController.clockIn);
router.post('/clock-out', attendanceController.clockOut);
router.post('/auto-clock-out', attendanceController.autoClockOut);
router.get('/workplace', attendanceController.getWorkplaceInfo);
router.get('/today/:staffId', attendanceController.getTodayAttendance);
router.get('/my/:staffId', attendanceController.getMyAttendance);

module.exports = router;
