const User = require('../models/User');
const Attendance = require('../models/Attendance');
const PayslipRecord = require('../models/PayslipRecord');

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

function calcDeductions(gross) {
  const epf = Math.round(gross * 0.11 * 100) / 100;
  const socso = Math.min(Math.round(gross * 0.005 * 100) / 100, 29.75);
  return {
    epf,
    socso,
    net: Math.round((gross - epf - socso) * 100) / 100,
    deductions: [
      { code: 'EPF', label: 'EPF employee (est. 11%)', amount: epf },
      { code: 'SOCSO', label: 'SOCSO (est.)', amount: socso },
    ],
  };
}

/** Build payslip JSON for staff/supervisor (same shape as GET /staff/payslip). */
async function buildPayslipData(staffId, year, month) {
  const user = await User.findOne({ staffId }).select(
    'staffId name email department position salary role',
  );
  if (!user) {
    return { ok: false, status: 404, message: 'User not found' };
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
  const computed = calcDeductions(grossMonthly);
  const adminRecord = await PayslipRecord.findOne({ staffId, year, month }).lean();

  let netPay = computed.net;
  let grossForDisplay = grossMonthly;
  let deductions = computed.deductions;
  let disclaimer = 'System estimate only. Actual deductions follow HR / statutory rules.';
  let fromAdmin = false;
  let adminRemarks = '';
  let hasPdf = false;
  let pdfFileName = '';
  let pdfSource = '';

  if (adminRecord) {
    netPay = Number(adminRecord.netPay);
    grossForDisplay = adminRecord.grossPay > 0 ? Number(adminRecord.grossPay) : grossMonthly;
    adminRemarks = adminRecord.remarks || '';
    fromAdmin = true;
    disclaimer =
      'Payslip confirmed by admin. Deductions may be simplified — refer to HR for official documents.';
    if (adminRecord.grossPay > 0) {
      const d = calcDeductions(grossForDisplay);
      deductions = d.deductions;
    }
    hasPdf = Boolean(adminRecord.pdfFile);
    pdfFileName = adminRecord.pdfFileName || '';
    pdfSource = adminRecord.pdfSource || '';
  }

  return {
    ok: true,
    data: {
      periodLabel: `${MONTH_NAMES[month - 1]} ${year}`,
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
      hasPdf,
      pdfFileName,
      pdfSource,
    },
  };
}

function sanitizePayslipRecord(doc) {
  if (!doc) return doc;
  const o = typeof doc.toObject === 'function' ? doc.toObject() : { ...doc };
  o.hasPdf = Boolean(o.pdfFile);
  delete o.pdfFile;
  return o;
}

module.exports = {
  MONTH_NAMES,
  calcDeductions,
  buildPayslipData,
  sanitizePayslipRecord,
};
