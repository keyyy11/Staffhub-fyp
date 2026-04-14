const express = require('express');
const router = express.Router();
const supervisorController = require('../controllers/supervisorController');
const { requireAuth, requireSupervisor } = require('../middleware/authMiddleware');

router.use(requireAuth);
router.use(requireSupervisor);

router.get('/team', supervisorController.getTeam);
router.get('/config', supervisorController.getConfig);
router.get('/attendance-report', supervisorController.getAttendanceReport);
router.get('/leave-requests', supervisorController.getLeaveRequests);
router.get('/notifications', supervisorController.getNotifications);
router.put('/notifications/:id/read', supervisorController.markNotificationRead);
router.put('/notifications/read-all', supervisorController.markAllNotificationsRead);
router.get('/staff/:staffId/schedule', supervisorController.getStaffSchedule);
router.put('/staff/:staffId/schedule', supervisorController.putStaffSchedule);

module.exports = router;
