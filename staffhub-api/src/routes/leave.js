const express = require('express');
const router = express.Router();
const leaveController = require('../controllers/leaveController');

router.get('/balance/:staffId', leaveController.getBalance);
router.post('/apply', leaveController.applyLeave);
router.get('/requests/:staffId', leaveController.getMyRequests);
router.get('/mc/:requestId', leaveController.getMcLetter);

module.exports = router;
