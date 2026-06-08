const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const branchController = require('../controllers/branchController');
const warningController = require('../controllers/warningController');
const overtimeController = require('../controllers/overtimeController');
const { requireAuth, requireAdmin } = require('../middleware/authMiddleware');

router.use(requireAuth);
router.use(requireAdmin);

router.get('/me', adminController.getAdminMe);
router.put('/me', adminController.updateAdminMe);

router.get('/attendance-report', adminController.getAttendanceReport);
router.get('/staff-list', adminController.getStaffList);
router.get('/branches', branchController.listBranches);
router.post('/branches', branchController.createBranch);
router.put('/branches/:branchCode', branchController.updateBranch);
router.delete('/branches/:branchCode', branchController.deleteBranch);
router.post('/register-staff', adminController.registerStaff);
router.put('/staff/:staffId/salary', adminController.updateStaffSalary);
router.put('/staff/:staffId/supervisor', adminController.assignSupervisor);
router.put('/staff/:staffId/promote-supervisor', adminController.promoteStaffToSupervisor);
router.get('/staff/:staffId/schedule', adminController.getStaffSchedule);
router.put('/staff/:staffId/schedule', adminController.putStaffSchedule);
router.put('/staff/:staffId', adminController.updateStaffByAdmin);
router.get('/config', adminController.getConfig);
router.get('/leave-requests', adminController.getLeaveRequests);
router.get('/leave-requests/:id/mc', adminController.getLeaveRequestMcLetter);
router.put('/leave-requests/:id', adminController.updateLeaveRequestStatus);
router.get('/overtime-requests', overtimeController.getAllOvertimeRequests);
router.get('/payslip-records', adminController.getPayslipRecords);
router.post('/payslip-record', adminController.upsertPayslipRecord);

router.get('/staff/:staffId/discipline-metrics', warningController.getStaffDisciplineMetrics);
router.get('/warnings', warningController.listWarnings);
router.post('/warnings', warningController.createWarning);

module.exports = router;
