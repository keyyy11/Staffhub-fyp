const express = require('express');
const router = express.Router();
const supervisorController = require('../controllers/supervisorController');
const overtimeController = require('../controllers/overtimeController');
const performanceController = require('../controllers/performanceController');
const payslipController = require('../controllers/payslipController');
const { requireAuth, requireSupervisor } = require('../middleware/authMiddleware');

router.use(requireAuth);
router.use(requireSupervisor);

router.get('/team', supervisorController.getTeam);
router.get('/org-staff', supervisorController.getOrgStaff);
router.get('/org-leave-requests', supervisorController.getOrgLeaveRequests);
router.get('/org-overtime-requests', overtimeController.getOrgOvertimeRequests);
router.get('/config', supervisorController.getConfig);
router.get('/attendance-report', supervisorController.getAttendanceReport);
router.get('/leave-requests', supervisorController.getLeaveRequests);
router.get('/leave-requests/:id/mc', supervisorController.getLeaveRequestMcLetter);
router.put('/leave-requests/:id', supervisorController.supervisorUpdateLeaveRequest);
router.get('/overtime-requests', overtimeController.getTeamOvertimeRequests);
router.put('/overtime-requests/:id', overtimeController.supervisorDecideOvertime);
router.get('/notifications', supervisorController.getNotifications);
router.put('/notifications/:id/read', supervisorController.markNotificationRead);
router.put('/notifications/read-all', supervisorController.markAllNotificationsRead);
router.get('/staff/:staffId/schedule', supervisorController.getStaffSchedule);
router.put('/staff/:staffId/schedule', supervisorController.putStaffSchedule);
router.get('/staff/:staffId/performance', performanceController.getStaffPerformanceSupervisor);
router.get('/payslip-records', payslipController.getSupervisorTeamPayslipRecords);
router.get('/staff/:staffId/payslip', payslipController.getSupervisorStaffPayslip);
router.get('/staff/:staffId/payslip/pdf', payslipController.getSupervisorStaffPayslipPdf);

module.exports = router;
