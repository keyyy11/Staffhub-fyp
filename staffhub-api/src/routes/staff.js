const express = require('express');
const router = express.Router();
const staffController = require('../controllers/staffController');
const warningController = require('../controllers/warningController');
const overtimeController = require('../controllers/overtimeController');
const { requireAuth, requireStaff } = require('../middleware/authMiddleware');

router.get('/work-schedule', staffController.getWorkSchedule);
router.get('/my-work-schedule', requireAuth, staffController.getMyWorkSchedule);
router.get('/payslip/:staffId', staffController.getPayslip);

router.get('/warnings', requireAuth, warningController.getMyWarnings);

/** No auth — use to verify the API you hit has OT routes (GET should return JSON, not 404). */
router.get('/overtime/ping', (req, res) => {
  res.json({ success: true, message: 'Overtime routes are active on this server' });
});

router.post('/overtime/apply', requireAuth, requireStaff, overtimeController.applyOvertime);
router.get('/overtime/my', requireAuth, requireStaff, overtimeController.getMyOvertimeRequests);

module.exports = router;
