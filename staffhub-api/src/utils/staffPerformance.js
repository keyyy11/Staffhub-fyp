const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const OvertimeRequest = require('../models/OvertimeRequest');
const WarningLetter = require('../models/WarningLetter');
const workplace = require('../config/workplace');

function isClockInLate(clockInDate) {
  const clockIn = new Date(clockInDate);
  const expected = new Date(clockIn);
  expected.setHours(workplace.expectedClockInHour, workplace.expectedClockInMinute, 0, 0);
  return clockIn > expected;
}

function performanceGrade(score) {
  if (score >= 90) return 'Excellent';
  if (score >= 75) return 'Good';
  if (score >= 60) return 'Fair';
  return 'Needs Improvement';
}

/**
 * Compute staff performance analytics for the last [days] days.
 * @returns {Promise<object|null>}
 */
async function computeStaffPerformance(staffId, days = 90) {
  const staff = await User.findOne({
    staffId: String(staffId).trim(),
    role: { $in: ['staff', 'supervisor'] },
  })
    .select('staffId name role supervisorStaffId department position')
    .lean();

  if (!staff) return null;

  const periodDays = Math.min(Math.max(parseInt(days, 10) || 90, 7), 365);
  const start = new Date();
  start.setDate(start.getDate() - periodDays);
  start.setHours(0, 0, 0, 0);
  const end = new Date();
  end.setHours(23, 59, 59, 999);

  const attendances = await Attendance.find({
    staffId: staff.staffId,
    date: { $gte: start, $lte: end },
    clockIn: { $ne: null },
  }).lean();

  let lateCount = 0;
  let onTimeCount = 0;
  for (const a of attendances) {
    if (isClockInLate(a.clockIn)) lateCount += 1;
    else onTimeCount += 1;
  }
  const totalAttendance = attendances.length;
  const attendanceRate = totalAttendance > 0
    ? Math.round((onTimeCount / totalAttendance) * 100)
    : 100;

  const leaveRows = await LeaveRequest.find({
    staffId: staff.staffId,
    createdAt: { $gte: start, $lte: end },
  }).lean();

  let leaveApproved = 0;
  let leaveRejected = 0;
  let leavePending = 0;
  let leaveDaysApproved = 0;
  for (const r of leaveRows) {
    if (r.status === 'approved') {
      leaveApproved += 1;
      leaveDaysApproved += Number(r.totalDays) || 0;
    } else if (r.status === 'rejected') leaveRejected += 1;
    else leavePending += 1;
  }

  const otRows = await OvertimeRequest.find({
    staffId: staff.staffId,
    otDate: { $gte: start, $lte: end },
  }).lean();

  let otApproved = 0;
  let otRejected = 0;
  let otPending = 0;
  let otHoursApproved = 0;
  for (const r of otRows) {
    if (r.status === 'approved') {
      otApproved += 1;
      otHoursApproved += Number(r.hours) || 0;
    } else if (r.status === 'rejected') otRejected += 1;
    else otPending += 1;
  }
  otHoursApproved = Math.round(otHoursApproved * 10) / 10;

  const warningCount = await WarningLetter.countDocuments({
    staffId: staff.staffId,
    createdAt: { $gte: start, $lte: end },
  });

  let performanceScore = Math.round(
    attendanceRate * 0.55
    + Math.min(otHoursApproved, 24) * 1.2
    - lateCount * 2
    - leaveRejected * 4
    - warningCount * 5,
  );
  performanceScore = Math.max(0, Math.min(100, performanceScore));

  return {
    staffId: staff.staffId,
    staffName: staff.name,
    role: staff.role,
    department: staff.department || '',
    position: staff.position || '',
    supervisorStaffId: staff.supervisorStaffId || '',
    periodDays,
    attendance: {
      total: totalAttendance,
      onTime: onTimeCount,
      late: lateCount,
      rate: attendanceRate,
    },
    leave: {
      approved: leaveApproved,
      rejected: leaveRejected,
      pending: leavePending,
      daysApproved: leaveDaysApproved,
    },
    overtime: {
      approved: otApproved,
      rejected: otRejected,
      pending: otPending,
      hoursApproved: otHoursApproved,
    },
    warnings: { count: warningCount },
    performanceScore,
    performanceGrade: performanceGrade(performanceScore),
    onTimeRatio: totalAttendance > 0 ? Math.round((onTimeCount / totalAttendance) * 1000) / 1000 : 1,
    eligibleLateWarning: lateCount >= 5,
    eligibleUnsatisfactoryWarning:
      leaveRejected >= 2
      || (totalAttendance >= 10 && onTimeCount / totalAttendance < 0.6)
      || (lateCount >= 3 && leaveRejected >= 1),
  };
}

module.exports = { computeStaffPerformance, performanceGrade };
