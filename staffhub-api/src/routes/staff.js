const express = require('express');
const router = express.Router();
const staffController = require('../controllers/staffController');
const warningController = require('../controllers/warningController');
const { requireAuth } = require('../middleware/authMiddleware');

router.get('/work-schedule', staffController.getWorkSchedule);
router.get('/payslip/:staffId', staffController.getPayslip);

router.get('/warnings', requireAuth, warningController.getMyWarnings);

module.exports = router;
