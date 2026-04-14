const LeaveBalance = require('../models/LeaveBalance');
const LeaveRequest = require('../models/LeaveRequest');

async function getOrCreateBalance(staffId, year) {
  let balance = await LeaveBalance.findOne({ staffId, year });
  if (!balance) {
    balance = await LeaveBalance.create({ staffId, year });
  }
  return balance;
}

function formatBalance(leave) {
  return {
    total: leave.total,
    used: leave.used,
    remaining: Math.max(0, leave.total - leave.used),
  };
}

exports.getBalance = async (req, res) => {
  try {
    const { staffId } = req.params;
    const year = parseInt(req.query.year, 10) || new Date().getFullYear();

    if (!staffId) {
      return res.status(400).json({
        success: false,
        message: 'staffId is required',
      });
    }

    const balance = await getOrCreateBalance(staffId, year);

    res.json({
      success: true,
      data: {
        year: balance.year,
        medicalLeave: formatBalance(balance.medicalLeave),
        annualLeave: formatBalance(balance.annualLeave),
        unpaidLeave: formatBalance(balance.unpaidLeave),
        otherLeave: formatBalance(balance.otherLeave),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

function getBusinessDays(startDate, endDate) {
  let count = 0;
  const start = new Date(startDate);
  const end = new Date(endDate);
  const current = new Date(start);
  while (current <= end) {
    const dayOfWeek = current.getDay();
    if (dayOfWeek !== 0 && dayOfWeek !== 6) count++;
    current.setDate(current.getDate() + 1);
  }
  return count;
}

exports.applyLeave = async (req, res) => {
  try {
    const { staffId, leaveType, startDate, endDate, reason } = req.body;

    if (!staffId || !leaveType || !startDate || !endDate) {
      return res.status(400).json({
        success: false,
        message: 'staffId, leaveType, startDate and endDate are required',
      });
    }

    const validTypes = ['medical', 'annual', 'unpaid', 'other'];
    if (!validTypes.includes(leaveType)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid leave type',
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start > end) {
      return res.status(400).json({
        success: false,
        message: 'End date must be after start date',
      });
    }

    const totalDays = getBusinessDays(start, end);

    const year = start.getFullYear();
    const balance = await getOrCreateBalance(staffId, year);
    let leaveBalance;

    switch (leaveType) {
      case 'medical': leaveBalance = balance.medicalLeave; break;
      case 'annual': leaveBalance = balance.annualLeave; break;
      case 'unpaid': leaveBalance = balance.unpaidLeave; break;
      case 'other': leaveBalance = balance.otherLeave; break;
      default: leaveBalance = { total: 0, used: 0 };
    }

    const remaining = leaveBalance.total - leaveBalance.used;
    if (leaveType !== 'unpaid' && totalDays > remaining) {
      return res.status(400).json({
        success: false,
        message: `Insufficient leave balance. You have ${remaining} days remaining.`,
      });
    }

    const request = await LeaveRequest.create({
      staffId,
      leaveType,
      startDate: start,
      endDate: end,
      totalDays,
      reason: reason || '',
    });

    res.status(201).json({
      success: true,
      message: 'Leave application submitted successfully',
      data: request,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getMyRequests = async (req, res) => {
  try {
    const { staffId } = req.params;
    const limit = parseInt(req.query.limit, 10) || 20;

    if (!staffId) {
      return res.status(400).json({
        success: false,
        message: 'staffId is required',
      });
    }

    const requests = await LeaveRequest.find({ staffId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    res.json({
      success: true,
      data: requests,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
