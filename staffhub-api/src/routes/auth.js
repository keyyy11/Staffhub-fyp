const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/register', authController.register);
router.post('/register-admin', authController.registerAdmin);
router.post('/register-supervisor', authController.registerSupervisor);
router.post('/login', authController.login);
router.post('/change-password', requireAuth, authController.changePassword);

module.exports = router;
