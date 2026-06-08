const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const LeaveBalance = require('../models/LeaveBalance');
const PayslipRecord = require('../models/PayslipRecord');
const OvertimeRequest = require('../models/OvertimeRequest');
const StaffSchedule = require('../models/StaffSchedule');
const Notification = require('../models/Notification');
const WarningLetter = require('../models/WarningLetter');
const workplace = require('../config/workplace');
const Branch = require('../models/Branch');
const { allocateNextId, AUTO_STAFF_PREFIX, AUTO_SUPERVISOR_PREFIX } = require('../utils/staffIdAllocator');
const { normalizeScheduleDays, normalizeDateEntries } = require('../utils/scheduleDays');

/**
 * Move all app data keyed by oldId to newId (same person). Does not change the User row
 * for that person — caller sets user.staffId and saves after this.
 * Updates other users' supervisorStaffId when they report to oldId.
 */
async function reassignStaffIdDataToNewId(oldId, newId) {
  await User.updateMany({ supervisorStaffId: oldId }, { $set: { supervisorStaffId: newId } });
  await Attendance.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await LeaveRequest.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await LeaveBalance.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await PayslipRecord.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await WarningLetter.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await OvertimeRequest.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await OvertimeRequest.updateMany({ supervisorStaffIdAtSubmit: oldId }, { $set: { supervisorStaffIdAtSubmit: newId } });
  await OvertimeRequest.updateMany({ approverStaffId: oldId }, { $set: { approverStaffId: newId } });
  await OvertimeRequest.updateMany(
    { 'flow.actorStaffId': oldId },
    { $set: { 'flow.$[elem].actorStaffId': newId } },
    { arrayFilters: [{ 'elem.actorStaffId': oldId }] },
  );
  await StaffSchedule.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
  await Notification.updateMany({ staffId: oldId }, { $set: { staffId: newId } });
}

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
      .select('staffId name email phone department position salary role supervisorStaffId branchCode')
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

/** Change a staff account to supervisor (same email/password; clears reporting line). Admin-only (router + check).
 * Optional body: { newStaffId } — if set, reassign all records to the new ID before promoting (user must log in with new ID).
 */
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

    let newStaffIdRaw = req.body && req.body.newStaffId != null ? String(req.body.newStaffId).trim() : '';
    const autoSupervisorId = req.body && (req.body.autoSupervisorId === true || String(req.body.newStaffId || '').toLowerCase() === 'auto');
    if (autoSupervisorId) {
      newStaffIdRaw = await allocateNextId(AUTO_SUPERVISOR_PREFIX);
    }

    if (newStaffIdRaw) {
      if (!autoSupervisorId) {
        if (newStaffIdRaw === user.staffId) {
          return res.status(400).json({
            success: false,
            message: 'newStaffId must be different from the current Staff ID.',
          });
        }
        if (newStaffIdRaw.length < 2 || newStaffIdRaw.length > 64) {
          return res.status(400).json({
            success: false,
            message: 'newStaffId must be between 2 and 64 characters.',
          });
        }
        const taken = await User.findOne({ staffId: newStaffIdRaw });
        if (taken) {
          return res.status(400).json({
            success: false,
            message: 'That Staff ID is already in use. Choose another.',
          });
        }
      }
      await reassignStaffIdDataToNewId(user.staffId, newStaffIdRaw);
      user.staffId = newStaffIdRaw;
    }

    user.role = 'supervisor';
    user.supervisorStaffId = '';
    await user.save();
    res.json({
      success: true,
      message: newStaffIdRaw
        ? 'Staff promoted to supervisor with a new supervisor ID. Historical data now uses this ID; the old staff ID is no longer used. Ask them to sign in again (same email and password).'
        : 'Staff promoted to supervisor',
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

/** Admin creates a new staff account (no self-registration token returned to admin).
 * Omit staffId or set autoStaffId: true / staffId: "auto" to allocate STF001, STF002, …
 */
exports.registerStaff = async (req, res) => {
  try {
    const { name, email, password, autoStaffId, branchCode } = req.body;
    let staffId = req.body.staffId != null ? String(req.body.staffId).trim() : '';
    const useAutoStaffId = autoStaffId === true || !staffId || staffId.toLowerCase() === 'auto';

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, email, and password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    if (useAutoStaffId) {
      staffId = await allocateNextId(AUTO_STAFF_PREFIX);
    }

    if (!staffId || staffId.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID is required, or enable automatic ID (autoStaffId / leave staffId empty)',
      });
    }

    if (staffId.length > 64) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID must be at most 64 characters',
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { staffId }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email ? 'Email already registered' : 'Staff ID already exists',
      });
    }

    const userPayload = { staffId, name, email, password, role: 'staff' };
    if (branchCode !== undefined && String(branchCode).trim()) {
      const code = String(branchCode).trim().toUpperCase();
      const branch = await Branch.findOne({ branchCode: code, isActive: true });
      if (!branch) {
        return res.status(400).json({ success: false, message: 'Invalid or inactive branch code' });
      }
      userPayload.branchCode = code;
    }

    const user = await User.create(userPayload);

    res.status(201).json({
      success: true,
      message: 'Staff registered successfully',
      data: {
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        role: 'staff',
        branchCode: user.branchCode || '',
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Admin: update staff/supervisor profile fields; optional newPassword (min 6 chars). */
exports.updateStaffByAdmin = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { name, email, phone, department, position, newPassword, branchCode } = req.body;
    const user = await User.findOne({ staffId, role: { $in: ['staff', 'supervisor'] } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Staff or supervisor not found' });
    }
    if (email !== undefined && String(email).trim().toLowerCase() !== user.email) {
      const em = String(email).toLowerCase().trim();
      const taken = await User.findOne({ email: em });
      if (taken && taken.staffId !== staffId) {
        return res.status(400).json({ success: false, message: 'Email already in use' });
      }
      user.email = em;
    }
    if (name !== undefined) user.name = String(name).trim();
    if (phone !== undefined) user.phone = String(phone).trim();
    if (department !== undefined) user.department = String(department).trim();
    if (position !== undefined) user.position = String(position).trim();
    if (branchCode !== undefined) {
      const code = String(branchCode).trim().toUpperCase();
      if (!code) {
        user.branchCode = '';
      } else {
        const branch = await Branch.findOne({ branchCode: code, isActive: true });
        if (!branch) {
          return res.status(400).json({ success: false, message: 'Invalid or inactive branch code' });
        }
        user.branchCode = code;
      }
    }
    if (newPassword !== undefined && String(newPassword).length > 0) {
      if (String(newPassword).length < 6) {
        return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
      }
      user.password = String(newPassword);
    }
    await user.save();
    res.json({
      success: true,
      message: 'Staff updated',
      data: {
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        department: user.department || '',
        position: user.position || '',
        role: user.role,
        supervisorStaffId: user.supervisorStaffId || '',
        branchCode: user.branchCode || '',
        salary: user.salary,
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
    const requests = await LeaveRequest.find(filter).select('-mcLetter').sort({ createdAt: -1 }).limit(200).lean();
    const staffIds = [...new Set(requests.map((r) => r.staffId))];
    const users = await User.find({ staffId: { $in: staffIds } }).select('staffId name supervisorStaffId').lean();
    const nameMap = Object.fromEntries(users.map((u) => [u.staffId, u.name]));
    const supIds = [...new Set(users.map((u) => u.supervisorStaffId).filter((id) => id && String(id).trim()))];
    const supervisors = await User.find({ staffId: { $in: supIds }, role: 'supervisor' }).select('staffId name').lean();
    const supNameMap = Object.fromEntries(supervisors.map((s) => [s.staffId, s.name]));
    const userByStaffId = Object.fromEntries(users.map((u) => [u.staffId, u]));
    const data = requests.map((r) => {
      const u = userByStaffId[r.staffId];
      const supId = u && u.supervisorStaffId ? String(u.supervisorStaffId).trim() : '';
      const supervisorName = supId ? supNameMap[supId] || supId : '';
      return {
        ...r,
        staffName: nameMap[r.staffId] || r.staffId,
        supervisorName,
        supervisorStaffId: supId,
      };
    });
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
    lr.decidedByRole = 'admin';
    lr.decidedByStaffId = req.user.staffId || '';
    lr.decidedByName = req.user.name || '';
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

exports.getLeaveRequestMcLetter = async (req, res) => {
  try {
    const { id } = req.params;
    const request = await LeaveRequest.findById(id).select('+mcLetter').lean();
    if (!request) {
      return res.status(404).json({ success: false, message: 'Leave request not found' });
    }
    if (!request.hasMcLetter || !request.mcLetter) {
      return res.status(404).json({ success: false, message: 'No MC letter attached to this request' });
    }
    res.json({
      success: true,
      data: {
        mcLetter: request.mcLetter,
        mcLetterFileName: request.mcLetterFileName || 'mc-letter.jpg',
      },
    });
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

/** Admin: weekly timetable for any staff/supervisor (same shape as supervisor schedule). */
exports.getStaffSchedule = async (req, res) => {
  try {
    const { staffId } = req.params;
    const target = await User.findOne({ staffId, role: { $in: ['staff', 'supervisor'] } });
    if (!target) {
      return res.status(404).json({ success: false, message: 'Staff or supervisor not found' });
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
    const { days, dateEntries, notes } = req.body;
    const target = await User.findOne({ staffId, role: { $in: ['staff', 'supervisor'] } });
    if (!target) {
      return res.status(404).json({ success: false, message: 'Staff or supervisor not found' });
    }
    if (!Array.isArray(days) && !Array.isArray(dateEntries)) {
      return res.status(400).json({ success: false, message: 'Provide days (weekly) and/or dateEntries (ikut tarikh)' });
    }
    const $set = {
      notes: notes != null ? String(notes) : '',
      updatedBy: req.user._id,
    };
    if (Array.isArray(days)) {
      $set.days = normalizeScheduleDays(days);
    }
    if (Array.isArray(dateEntries)) {
      $set.dateEntries = normalizeDateEntries(dateEntries);
    }
    const doc = await StaffSchedule.findOneAndUpdate({ staffId }, { $set }, { upsert: true, new: true });
    res.json({ success: true, message: 'Schedule saved', data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
