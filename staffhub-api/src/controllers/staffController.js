const User = require('../models/User');
const Attendance = require('../models/Attendance');
const PayslipRecord = require('../models/PayslipRecord');
const workplace = require('../config/workplace');

function pad2(n) {
  return String(n).padStart(2, '0');
}

function timeStr(h, m) {
  return `${pad2(h)}:${pad2(m)}`;
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

  res.json({
    success: true,
    data: {
      timezone: 'Asia/Kuala_Lumpur',
      expectedClockIn: expectedIn,
      notes: 'Ideal clock-in: on or before the expected time. Lunch break is included in the working window.',
      weeklySchedule: days,
    },
  });
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
