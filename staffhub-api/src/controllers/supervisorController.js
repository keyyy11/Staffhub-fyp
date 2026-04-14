const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const Notification = require('../models/Notification');
const StaffSchedule = require('../models/StaffSchedule');
const workplace = require('../config/workplace');

function isClockInLate(clockInDate) {
  const clockIn = new Date(clockInDate);
  const expected = new Date(clockIn);
  expected.setHours(workplace.expectedClockInHour, workplace.expectedClockInMinute, 0, 0);
  return clockIn > expected;
}

function formatTime(date) {
  const d = new Date(date);
  return d.toTimeString().slice(0, 5);
}

async function getTeamStaffIds(supervisorStaffId) {
  const team = await User.find({ role: 'staff', supervisorStaffId }).select('staffId').lean();
  return team.map((t) => t.staffId);
}

exports.getTeam = async (req, res) => {
  try {
    const team = await User.find({ role: 'staff', supervisorStaffId: req.user.staffId })
      .select('staffId name email department position')
      .sort({ staffId: 1 })
      .lean();
    res.json({ success: true, data: team });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAttendanceReport = async (req, res) => {
  try {
    const teamIds = await getTeamStaffIds(req.user.staffId);
    if (teamIds.length === 0) {
      return res.json({
        success: true,
        data: {
          report: [],
          stats: { total: 0, onTime: 0, late: 0 },
        },
      });
    }

    const { startDate, endDate, staffId } = req.query;
    const start = startDate ? new Date(startDate) : new Date(new Date().setDate(new Date().getDate() - 30));
    const end = endDate ? new Date(endDate) : new Date();
    start.setHours(0, 0, 0, 0);
    end.setHours(23, 59, 59, 999);

    const filter = { date: { $gte: start, $lte: end } };
    if (staffId && teamIds.includes(staffId)) {
      filter.staffId = staffId;
    } else {
      filter.staffId = { $in: teamIds };
    }

    const attendances = await Attendance.find(filter).sort({ date: -1, clockIn: -1 }).lean();
    const userMap = Object.fromEntries(
      (await User.find({ staffId: { $in: [...new Set(attendances.map((a) => a.staffId))] } }).select('staffId name').lean()).map((u) => [u.staffId, u]),
    );

    const report = attendances.map((a) => {
      const late = isClockInLate(a.clockIn);
      const user = userMap[a.staffId];
      return {
        _id: a._id,
        staffId: a.staffId,
        staffName: user?.name || a.staffId,
        date: a.date,
        clockIn: a.clockIn,
        clockOut: a.clockOut,
        clockInTime: formatTime(a.clockIn),
        clockOutTime: a.clockOut ? formatTime(a.clockOut) : null,
        status: late ? 'late' : 'on_time',
        expectedTime: `${String(workplace.expectedClockInHour).padStart(2, '0')}:${String(workplace.expectedClockInMinute).padStart(2, '0')}`,
      };
    });

    const stats = {
      total: report.length,
      onTime: report.filter((r) => r.status === 'on_time').length,
      late: report.filter((r) => r.status === 'late').length,
    };

    res.json({ success: true, data: { report, stats } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getLeaveRequests = async (req, res) => {
  try {
    const teamIds = await getTeamStaffIds(req.user.staffId);
    if (teamIds.length === 0) {
      return res.json({ success: true, data: [] });
    }
    const { status } = req.query;
    const filter = { staffId: { $in: teamIds } };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      filter.status = status;
    }
    const requests = await LeaveRequest.find(filter).sort({ createdAt: -1 }).limit(200).lean();
    const nameMap = Object.fromEntries(
      (await User.find({ staffId: { $in: teamIds } }).select('staffId name').lean()).map((u) => [u.staffId, u.name]),
    );
    const data = requests.map((r) => ({
      ...r,
      staffName: nameMap[r.staffId] || r.staffId,
    }));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const list = await Notification.find({ recipientId: req.user._id })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    const unread = await Notification.countDocuments({ recipientId: req.user._id, read: false });
    res.json({ success: true, data: { list, unreadCount: unread } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.markNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;
    const n = await Notification.findOne({ _id: id, recipientId: req.user._id });
    if (!n) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    n.read = true;
    await n.save();
    res.json({ success: true, data: n });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.markAllNotificationsRead = async (req, res) => {
  try {
    await Notification.updateMany({ recipientId: req.user._id, read: false }, { $set: { read: true } });
    res.json({ success: true, message: 'All marked read' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getStaffSchedule = async (req, res) => {
  try {
    const { staffId } = req.params;
    const teamIds = await getTeamStaffIds(req.user.staffId);
    if (!teamIds.includes(staffId)) {
      return res.status(403).json({ success: false, message: 'Not your team member' });
    }
    const doc = await StaffSchedule.findOne({ staffId }).lean();
    res.json({ success: true, data: doc || null });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.putStaffSchedule = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { days, notes } = req.body;
    const teamIds = await getTeamStaffIds(req.user.staffId);
    if (!teamIds.includes(staffId)) {
      return res.status(403).json({ success: false, message: 'Not your team member' });
    }
    if (!Array.isArray(days) || days.length === 0) {
      return res.status(400).json({ success: false, message: 'days array required (Mon–Sun)' });
    }
    const doc = await StaffSchedule.findOneAndUpdate(
      { staffId },
      {
        $set: {
          days,
          notes: notes != null ? String(notes) : '',
          updatedBy: req.user._id,
        },
      },
      { upsert: true, new: true },
    );
    res.json({ success: true, message: 'Schedule saved', data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getConfig = (req, res) => {
  res.json({
    success: true,
    data: {
      expectedClockIn: `${String(workplace.expectedClockInHour).padStart(2, '0')}:${String(workplace.expectedClockInMinute).padStart(2, '0')}`,
    },
  });
};
