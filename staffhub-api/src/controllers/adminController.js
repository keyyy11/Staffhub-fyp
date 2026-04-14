const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const LeaveBalance = require('../models/LeaveBalance');
const PayslipRecord = require('../models/PayslipRecord');
const workplace = require('../config/workplace');

async function getOrCreateBalance(staffId, year) {
  let balance = await LeaveBalance.findOne({ staffId, year });
  if (!balance) {
    balance = await LeaveBalance.create({ staffId, year });
  }
  return balance;
}

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

exports.getAttendanceReport = async (req, res) => {
  try {
    const { startDate, endDate, staffId } = req.query;
    const start = startDate ? new Date(startDate) : new Date(new Date().setDate(new Date().getDate() - 30));
    const end = endDate ? new Date(endDate) : new Date();
    start.setHours(0, 0, 0, 0);
    end.setHours(23, 59, 59, 999);

    const filter = { date: { $gte: start, $lte: end } };
    if (staffId) filter.staffId = staffId;

    const attendances = await Attendance.find(filter).sort({ date: -1, clockIn: -1 }).lean();

    const staffIds = [...new Set(attendances.map((a) => a.staffId))];
    const users = await User.find({ staffId: { $in: staffIds } }).select('staffId name').lean();
    const userMap = Object.fromEntries(users.map((u) => [u.staffId, u]));

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

exports.getStaffList = async (req, res) => {
  try {
    const staff = await User.find({ role: { $in: ['staff', 'supervisor'] } })
      .select('staffId name email department position salary role supervisorStaffId')
      .sort({ staffId: 1 })
      .lean();

    res.json({ success: true, data: staff });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Assign which supervisor (by supervisor's staffId) this staff reports to. */
exports.assignSupervisor = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { supervisorStaffId } = req.body;
    if (supervisorStaffId === undefined) {
      return res.status(400).json({ success: false, message: 'supervisorStaffId required (empty string to clear)' });
    }
    const staff = await User.findOne({ staffId, role: 'staff' });
    if (!staff) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    const trimmed = String(supervisorStaffId).trim();
    if (trimmed) {
      const sup = await User.findOne({ staffId: trimmed, role: 'supervisor' });
      if (!sup) {
        return res.status(400).json({ success: false, message: 'Supervisor staff ID not found or not a supervisor' });
      }
    }
    staff.supervisorStaffId = trimmed;
    await staff.save();
    res.json({
      success: true,
      message: 'Supervisor assignment updated',
      data: { staffId: staff.staffId, supervisorStaffId: staff.supervisorStaffId },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Change a staff account to supervisor (same email/password; clears reporting line). Admin-only (router + check). */
exports.promoteStaffToSupervisor = async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Only administrators can promote staff to supervisor' });
    }
    const { staffId } = req.params;
    const user = await User.findOne({ staffId });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No account with this Staff ID. Register the user first or check the ID.',
      });
    }
    if (user.role === 'supervisor') {
      return res.status(409).json({
        success: false,
        message: 'This account is already a supervisor.',
      });
    }
    if (user.role === 'admin') {
      return res.status(400).json({
        success: false,
        message: 'Cannot promote an administrator account.',
      });
    }
    if (user.role !== 'staff') {
      return res.status(400).json({
        success: false,
        message: 'Only staff accounts can be promoted to supervisor.',
      });
    }
    user.role = 'supervisor';
    user.supervisorStaffId = '';
    await user.save();
    res.json({
      success: true,
      message: 'Staff promoted to supervisor',
      data: {
        staffId: user.staffId,
        name: user.name,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateStaffSalary = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { salary } = req.body;

    if (salary === undefined || salary === null || salary < 0) {
      return res.status(400).json({ success: false, message: 'Valid salary required' });
    }

    const user = await User.findOneAndUpdate(
      { staffId, role: { $in: ['staff', 'supervisor'] } },
      { salary: Number(salary) },
      { new: true }
    ).select('staffId name salary role');

    if (!user) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }

    res.json({
      success: true,
      message: 'Salary updated successfully',
      data: user,
    });
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

/** Current admin profile (no password) */
exports.getAdminMe = async (req, res) => {
  try {
    const u = await User.findById(req.user._id).select('-password').lean();
    if (!u || u.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    res.json({
      success: true,
      data: {
        staffId: u.staffId,
        name: u.name,
        email: u.email,
        phone: u.phone || '',
        department: u.department || '',
        position: u.position || '',
        profileImage: u.profileImage || '',
        role: u.role,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateAdminMe = async (req, res) => {
  try {
    const { name, phone, department, position, profileImage } = req.body;
    const u = await User.findById(req.user._id);
    if (!u || u.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    if (name !== undefined) u.name = name;
    if (phone !== undefined) u.phone = phone;
    if (department !== undefined) u.department = department;
    if (position !== undefined) u.position = position;
    if (profileImage !== undefined) u.profileImage = profileImage;
    await u.save();
    res.json({
      success: true,
      message: 'Profile updated',
      data: {
        staffId: u.staffId,
        name: u.name,
        email: u.email,
        phone: u.phone || '',
        department: u.department || '',
        position: u.position || '',
        profileImage: u.profileImage || '',
        role: u.role,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Admin creates a new staff account (no self-registration token returned to admin) */
exports.registerStaff = async (req, res) => {
  try {
    const { staffId, name, email, password } = req.body;

    if (!staffId || !name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please fill all fields: staffId, name, email, password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { staffId }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email ? 'Email already registered' : 'Staff ID already exists',
      });
    }

    const user = await User.create({ staffId, name, email, password, role: 'staff' });

    res.status(201).json({
      success: true,
      message: 'Staff registered successfully',
      data: {
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        role: 'staff',
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Senarai semua permohonan cuti (tapis ?status=pending|approved|rejected) */
exports.getLeaveRequests = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {};
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      filter.status = status;
    }
    const requests = await LeaveRequest.find(filter).sort({ createdAt: -1 }).limit(200).lean();
    const staffIds = [...new Set(requests.map((r) => r.staffId))];
    const users = await User.find({ staffId: { $in: staffIds } }).select('staffId name').lean();
    const nameMap = Object.fromEntries(users.map((u) => [u.staffId, u.name]));
    const data = requests.map((r) => ({
      ...r,
      staffName: nameMap[r.staffId] || r.staffId,
    }));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateLeaveRequestStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminComment } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be approved or rejected' });
    }
    const lr = await LeaveRequest.findById(id);
    if (!lr) {
      return res.status(404).json({ success: false, message: 'Leave request not found' });
    }
    if (lr.status !== 'pending') {
      return res.status(400).json({ success: false, message: 'Request already processed' });
    }
    lr.status = status;
    if (adminComment !== undefined && adminComment !== null) {
      lr.adminComment = String(adminComment).trim();
    }
    await lr.save();

    if (status === 'approved') {
      const year = new Date(lr.startDate).getFullYear();
      const balance = await getOrCreateBalance(lr.staffId, year);
      const days = lr.totalDays;
      switch (lr.leaveType) {
        case 'medical':
          balance.medicalLeave.used += days;
          break;
        case 'annual':
          balance.annualLeave.used += days;
          break;
        case 'unpaid':
          balance.unpaidLeave.used += days;
          break;
        case 'other':
          balance.otherLeave.used += days;
          break;
        default:
          break;
      }
      await balance.save();
    }

    res.json({ success: true, message: `Leave ${status}`, data: lr });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getPayslipRecords = async (req, res) => {
  try {
    const { staffId, year, month } = req.query;
    const filter = {};
    if (staffId) filter.staffId = staffId;
    if (year) filter.year = parseInt(year, 10);
    if (month) filter.month = parseInt(month, 10);
    const list = await PayslipRecord.find(filter).sort({ year: -1, month: -1 }).limit(500).lean();
    res.json({ success: true, data: list });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.upsertPayslipRecord = async (req, res) => {
  try {
    const { staffId, year, month, netPay, grossPay, remarks } = req.body;
    if (!staffId || year == null || month == null || netPay == null) {
      return res.status(400).json({ success: false, message: 'staffId, year, month, netPay required' });
    }
    const y = parseInt(year, 10);
    const m = parseInt(month, 10);
    const net = Number(netPay);
    if (m < 1 || m > 12 || Number.isNaN(net) || Number.isNaN(y)) {
      return res.status(400).json({ success: false, message: 'Invalid year, month, or netPay' });
    }
    const user = await User.findOne({ staffId, role: 'staff' });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    const doc = await PayslipRecord.findOneAndUpdate(
      { staffId, year: y, month: m },
      {
        $set: {
          netPay: net,
          grossPay: grossPay != null ? Number(grossPay) : user.salary || 0,
          remarks: remarks || '',
          issuedBy: 'admin',
        },
      },
      { upsert: true, new: true },
    );
    res.json({ success: true, message: 'Payslip record saved', data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
