const express = require('express');
const router = express.Router();
const profileController = require('../controllers/profileController');

router.get('/:staffId', profileController.getProfile);
router.put('/:staffId', profileController.updateProfile);

module.exports = router;
