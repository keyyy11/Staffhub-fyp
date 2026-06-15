const User = require('../models/User');
const Attendance = require('../models/Attendance');
const LeaveRequest = require('../models/LeaveRequest');
const OvertimeRequest = require('../models/OvertimeRequest');
const PayslipRecord = require('../models/PayslipRecord');
const StaffSchedule = require('../models/StaffSchedule');
const workplace = require('../config/workplace');
const { enrichCalendarDays, PAY_NOTE_MS } = require('../config/publicHolidays');
const { coerceWorkingDay, deriveShiftTypeForApiRow, SHIFT_LABEL_MS, buildCalendarMonth } = require('../utils/scheduleDays');

function pad2(n) {
  return String(n).padStart(2, '0');
}

function timeStr(h, m) {
  return `${pad2(h)}:${pad2(m)}`;
}

function isClockInLate(clockInDate) {
  const clockIn = new Date(clockInDate);
  const expected = new Date(clockIn);
  expected.setHours(workplace.expectedClockInHour, workplace.expectedClockInMinute, 0, 0);
  return clockIn > expected;
}

function monthRange(year, month) {
  const start = new Date(year, month - 1, 1, 0, 0, 0, 0);
  const end = new Date(year, month, 0, 23, 59, 59, 999);
  return { start, end };
}

/** Weekly schedule — Mon–Fri working, Sat–Sun off */
exports.getWorkSchedule = (req, res) => {
  const start = timeStr(workplace.workStartHour, workplace.workStartMinute);
  const end = timeStr(workplace.workEndHour, workplace.workEndMinute);
  const expectedIn = timeStr(workplace.expectedClockInHour, workplace.expectedClockInMinute);

  const days = [
    { day: 'Monday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
    { day: 'Tuesday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
    { day: 'Wednesday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
    { day: 'Thursday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
    { day: 'Friday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
    { day: 'Saturday', isWorkingDay: false },
    { day: 'Sunday', isWorkingDay: false },
  ];

  const weeklySchedule = days.map((def) => {
    const st = deriveShiftTypeForApiRow(null, def);
    return { ...def, shiftType: st, shiftLabel: SHIFT_LABEL_MS[st] };
  });

  const cy = req.query.year ? parseInt(req.query.year, 10) : NaN;
  const cm = req.query.month ? parseInt(req.query.month, 10) : NaN;
  let calendarMonth = [];
  let calendarYear = null;
  let calendarMonthNum = null;
  if (!Number.isNaN(cy) && !Number.isNaN(cm) && cm >= 1 && cm <= 12) {
    calendarMonth = enrichCalendarDays(buildCalendarMonth(cy, cm, {}, days));
    calendarYear = cy;
    calendarMonthNum = cm;
  }

  res.json({
    success: true,
    data: {
      timezone: 'Asia/Kuala_Lumpur',
      expectedClockIn: expectedIn,
      notes: 'Ideal clock-in: on or before the expected time. Lunch break is included in the working window.',
      weeklySchedule,
      publicHolidayPayNote: PAY_NOTE_MS,
      ...(calendarMonth.length > 0
        ? {
            calendarMonth,
            calendarYear,
            calendarMonthNum,
          }
        : {}),
    },
  });
};

/** Merged workplace default + supervisor-defined schedule (if any). Requires auth — staff sees own only. */
exports.getMyWorkSchedule = async (req, res) => {
  try {
    const staffId = req.user.staffId;
    const start = timeStr(workplace.workStartHour, workplace.workStartMinute);
    const end = timeStr(workplace.workEndHour, workplace.workEndMinute);
    const expectedIn = timeStr(workplace.expectedClockInHour, workplace.expectedClockInMinute);

    const defaultDays = [
      { day: 'Monday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
      { day: 'Tuesday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
      { day: 'Wednesday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
      { day: 'Thursday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
      { day: 'Friday', isWorkingDay: true, workStart: start, workEnd: end, breakMinutes: workplace.breakMinutes },
      { day: 'Saturday', isWorkingDay: false },
      { day: 'Sunday', isWorkingDay: false },
    ];

    const custom = await StaffSchedule.findOne({ staffId }).lean();
    let weeklySchedule = defaultDays.map((def) => {
      const st = deriveShiftTypeForApiRow(null, def);
      return { ...def, shiftType: st, shiftLabel: SHIFT_LABEL_MS[st] };
    });
    let source = 'default';
    let customNotes = '';

    const hasWeekly = custom && custom.days && custom.days.length > 0;
    const hasDate = custom && custom.dateEntries && custom.dateEntries.length > 0;

    if (hasWeekly) {
      source = 'custom';
      customNotes = custom.notes || '';
      const byDay = Object.fromEntries(custom.days.map((d) => [d.day, d]));
      weeklySchedule = defaultDays.map((def) => {
        const o = byDay[def.day];
        if (!o) {
          const st = deriveShiftTypeForApiRow(null, def);
          return { ...def, shiftType: st, shiftLabel: SHIFT_LABEL_MS[st] };
        }
        const merged = {
          day: def.day,
          isWorkingDay: coerceWorkingDay(o.isWorkingDay, def.isWorkingDay),
          workStart: o.workStart || def.workStart,
          workEnd: o.workEnd || def.workEnd,
          breakMinutes: def.breakMinutes,
        };
        const st = deriveShiftTypeForApiRow(o, def);
        return { ...merged, shiftType: st, shiftLabel: SHIFT_LABEL_MS[st] };
      });
    } else if (hasDate) {
      source = 'custom';
      customNotes = custom.notes || '';
    }

    const scheduleMode = hasDate ? 'byDate' : 'weekly';

    const now = new Date();
    const cy = req.query.year ? parseInt(req.query.year, 10) : now.getFullYear();
    const cm = req.query.month ? parseInt(req.query.month, 10) : now.getMonth() + 1;
    const calendarMonth =
      !Number.isNaN(cy) && !Number.isNaN(cm) && cm >= 1 && cm <= 12
        ? enrichCalendarDays(buildCalendarMonth(cy, cm, custom || {}, defaultDays))
        : [];

    res.json({
      success: true,
      data: {
        timezone: 'Asia/Kuala_Lumpur',
        expectedClockIn: expectedIn,
        source,
        scheduleMode,
        supervisorNotes: customNotes,
        dateEntries: custom?.dateEntries || [],
        weeklySchedule,
        calendarMonth,
        calendarYear: cy,
        calendarMonthNum: cm,
        publicHolidayPayNote: PAY_NOTE_MS,
        notes:
          source === 'custom'
            ? hasDate
              ? 'Jadual ikut tarikh — Isnin minggu ini boleh lain dari Isnin minggu depan. Lalai mingguan dipakai jika tiada rekod untuk tarikh tersebut.'
              : 'Custom weekly timetable (hari kerja, masa, cuti hari) — ditetapkan oleh pentadbir atau penyelia.'
            : 'Jadual syarikat lalai. Pentadbir atau penyelia boleh menetapkan jadual sendiri.',
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Slip gaji ringkas berdasarkan gaji bulanan (User.salary) + rekod kehadiran bulan tersebut */
exports.getPayslip = async (req, res) => {
  try {
    const { staffId } = req.params;
    const now = new Date();
    const year = req.query.year ? parseInt(req.query.year, 10) : now.getFullYear();
    const month = req.query.month ? parseInt(req.query.month, 10) : now.getMonth() + 1;

    if (Number.isNaN(year) || Number.isNaN(month) || month < 1 || month > 12) {
      return res.status(400).json({ success: false, message: 'Invalid year or month' });
    }

    const user = await User.findOne({ staffId }).select(
      'staffId name email department position salary',
    );
    if (!user) {
      return res.json({
        success: false,
        message: 'User not found',
      });
    }

    const rangeStart = new Date(year, month - 1, 1, 0, 0, 0, 0);
    const rangeEnd = new Date(year, month, 0, 23, 59, 59, 999);

    const records = await Attendance.find({
      staffId,
      date: { $gte: rangeStart, $lte: rangeEnd },
      clockOut: { $ne: null },
    })
      .sort({ date: 1 })
      .lean();

    let totalMinutes = 0;
    for (const r of records) {
      totalMinutes += (new Date(r.clockOut).getTime() - new Date(r.clockIn).getTime()) / 60000;
    }

    const grossMonthly = Number(user.salary) || 0;
    const epfEmployee = Math.round(grossMonthly * 0.11 * 100) / 100;
    const socso = Math.min(Math.round(grossMonthly * 0.005 * 100) / 100, 29.75);
    const computedNet = Math.round((grossMonthly - epfEmployee - socso) * 100) / 100;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    const adminRecord = await PayslipRecord.findOne({ staffId, year, month }).lean();

    let netPay = computedNet;
    let grossForDisplay = grossMonthly;
    let deductions = [
      { code: 'EPF', label: 'EPF employee (est. 11%)', amount: epfEmployee },
      { code: 'SOCSO', label: 'SOCSO (est.)', amount: socso },
    ];
    let disclaimer =
      'System estimate only. Actual deductions follow HR / statutory rules.';
    let fromAdmin = false;
    let adminRemarks = '';

    if (adminRecord) {
      netPay = Number(adminRecord.netPay);
      grossForDisplay = adminRecord.grossPay > 0 ? Number(adminRecord.grossPay) : grossMonthly;
      adminRemarks = adminRecord.remarks || '';
      fromAdmin = true;
      disclaimer =
        'Payslip confirmed by admin. Deductions may be simplified — refer to HR for official documents.';
      if (adminRecord.grossPay > 0) {
        const epf2 = Math.round(grossForDisplay * 0.11 * 100) / 100;
        const soc2 = Math.min(Math.round(grossForDisplay * 0.005 * 100) / 100, 29.75);
        deductions = [
          { code: 'EPF', label: 'EPF employee (est. 11%)', amount: epf2 },
          { code: 'SOCSO', label: 'SOCSO (est.)', amount: soc2 },
        ];
      }
    }

    res.json({
      success: true,
      data: {
        periodLabel: `${monthNames[month - 1]} ${year}`,
        month,
        year,
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        department: user.department || '',
        position: user.position || '',
        attendance: {
          daysWithCompleteClock: records.length,
          totalHoursWorked: Math.round((totalMinutes / 60) * 100) / 100,
        },
        earnings: {
          grossSalary: grossForDisplay,
          label: fromAdmin ? 'Gross salary (RM)' : 'Monthly gross salary (RM)',
        },
        deductions,
        netPay,
        fromAdmin,
        adminRemarks,
        disclaimer,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Staff personal dashboard: attendance, late, leave, OT, punctuality rate (current month). */
exports.getDashboardStats = async (req, res) => {
  try {
    const staffId = req.user?.staffId;
    if (!staffId) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const { start, end } = monthRange(year, month);

    const attendances = await Attendance.find({
      staffId,
      date: { $gte: start, $lte: end },
      clockIn: { $ne: null },
    }).lean();

    let lateAttendance = 0;
    for (const row of attendances) {
      if (isClockInLate(row.clockIn)) lateAttendance += 1;
    }
    const totalAttendance = attendances.length;
    const onTime = totalAttendance - lateAttendance;
    const attendanceRate = totalAttendance > 0
      ? Math.round((onTime / totalAttendance) * 100)
      : 100;

    const leaveRows = await LeaveRequest.find({
      staffId,
      status: 'approved',
      $or: [
        { startDate: { $gte: start, $lte: end } },
        { endDate: { $gte: start, $lte: end } },
      ],
    }).lean();
    const leaveTaken = leaveRows.reduce((sum, r) => sum + (Number(r.totalDays) || 0), 0);

    const otRows = await OvertimeRequest.find({
      staffId,
      status: 'approved',
      otDate: { $gte: start, $lte: end },
    }).lean();
    const overtimeHours = Math.round(
      otRows.reduce((sum, r) => sum + (Number(r.hours) || 0), 0) * 10,
    ) / 10;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    res.json({
      success: true,
      data: {
        year,
        month,
        periodLabel: `${monthNames[month - 1]} ${year}`,
        totalAttendance,
        lateAttendance,
        leaveTaken,
        overtimeHours,
        attendanceRate,
        onTime,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
