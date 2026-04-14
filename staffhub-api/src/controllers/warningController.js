const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const WarningLetter = require('../models/WarningLetter');
const workplace = require('../config/workplace');

function isClockInLate(clockInDate) {
  const clockIn = new Date(clockInDate);
  const expected = new Date(clockIn);
  expected.setHours(workplace.expectedClockInHour, workplace.expectedClockInMinute, 0, 0);
  return clockIn > expected;
}

exports.getStaffDisciplineMetrics = async (req, res) => {
  try {
    const { staffId } = req.params;
    const staff = await User.findOne({ staffId, role: 'staff' }).select('staffId name').lean();
    if (!staff) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }

    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 90, 7), 365);
    const start = new Date();
    start.setDate(start.getDate() - days);
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);

    const attendances = await Attendance.find({
      staffId,
      date: { $gte: start, $lte: end },
    }).lean();

    let lateCount = 0;
    let onTimeCount = 0;
    for (const a of attendances) {
      if (isClockInLate(a.clockIn)) lateCount += 1;
      else onTimeCount += 1;
    }
    const totalAttendanceDays = attendances.length;
    const onTimeRatio = totalAttendanceDays > 0 ? onTimeCount / totalAttendanceDays : 1;

    const leaveRequests = await LeaveRequest.find({
      staffId,
      createdAt: { $gte: start, $lte: end },
    }).lean();

    let leaveRejected = 0;
    let leaveApproved = 0;
    let leavePending = 0;
    for (const r of leaveRequests) {
      if (r.status === 'rejected') leaveRejected += 1;
      else if (r.status === 'approved') leaveApproved += 1;
      else leavePending += 1;
    }

    const eligibleLateWarning = lateCount >= 5;
    const eligibleUnsatisfactoryWarning =
      leaveRejected >= 2 ||
      (totalAttendanceDays >= 10 && onTimeRatio < 0.6) ||
      (lateCount >= 3 && leaveRejected >= 1);

    res.json({
      success: true,
      data: {
        staffId: staff.staffId,
        staffName: staff.name,
        periodDays: days,
        lateCount,
        onTimeCount,
        totalAttendanceDays,
        onTimeRatio: Math.round(onTimeRatio * 1000) / 1000,
        leaveRejected,
        leaveApproved,
        leavePending,
        eligibleLateWarning,
        eligibleUnsatisfactoryWarning,
        thresholds: {
          lateWarningMinLateCount: 5,
          unsatisfactoryRejectedLeave: 2,
          unsatisfactoryMinAttendanceDays: 10,
          unsatisfactoryMaxOnTimeRatio: 0.6,
          unsatisfactoryLatePlusRejected: { lateMin: 3, rejectedMin: 1 },
        },
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createWarning = async (req, res) => {
  try {
    const { staffId, category, notes } = req.body;
    if (!staffId || !category || !notes || String(notes).trim().length < 5) {
      return res.status(400).json({
        success: false,
        message: 'staffId, category, and notes (minimum 5 characters) are required',
      });
    }
    const valid = ['late_five_times', 'attendance_leave_unsatisfactory', 'other'];
    if (!valid.includes(category)) {
      return res.status(400).json({ success: false, message: 'Invalid category' });
    }
    const staff = await User.findOne({ staffId, role: 'staff' });
    if (!staff) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    const admin = await User.findById(req.user._id).select('name email');
    const doc = await WarningLetter.create({
      staffId,
      staffName: staff.name,
      category,
      notes: String(notes).trim(),
      issuedByAdminId: req.user._id,
      issuedByName: admin?.name || '',
      issuedByEmail: admin?.email || '',
    });
    res.status(201).json({ success: true, message: 'Warning letter issued', data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.listWarnings = async (req, res) => {
  try {
    const { staffId } = req.query;
    const filter = {};
    if (staffId) filter.staffId = staffId;
    const list = await WarningLetter.find(filter).sort({ createdAt: -1 }).limit(200).lean();
    res.json({ success: true, data: list });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getMyWarnings = async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ success: false, message: 'Staff access only' });
    }
    const list = await WarningLetter.find({ staffId: req.user.staffId })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();
    res.json({ success: true, data: list });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
