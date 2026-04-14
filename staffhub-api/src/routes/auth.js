const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

router.post('/register', authController.register);
router.post('/register-admin', authController.registerAdmin);
router.post('/register-supervisor', authController.registerSupervisor);
router.post('/login', authController.login);

module.exports = router;
