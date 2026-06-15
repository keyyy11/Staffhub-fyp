const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const accessLogController = require('../controllers/accessLogController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/register', authController.register);
router.post('/register-admin', authController.registerAdmin);
router.post('/register-supervisor', authController.registerSupervisor);
router.post('/login', authController.login);
router.post('/logout', requireAuth, accessLogController.logout);
router.post('/forgot-password', authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);
router.post('/change-password', requireAuth, authController.changePassword);

module.exports = router;
