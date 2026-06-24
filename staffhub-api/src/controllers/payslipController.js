const User = require('../models/User');
const PayslipRecord = require('../models/PayslipRecord');
const { buildPayslipData, sanitizePayslipRecord } = require('../utils/payslipData');
const { validatePayslipPdf } = require('../utils/payslipValidate');
const { generatePayslipPdfBuffer, bufferToPdfDataUrl } = require('../utils/payslipPdf');

async function findPayrollUser(staffId) {
  return User.findOne({ staffId, role: { $in: ['staff', 'supervisor'] } });
}

async function assertSupervisorCanView(supervisorStaffId, targetStaffId) {
  if (supervisorStaffId === targetStaffId) return true;
  const member = await User.findOne({
    staffId: targetStaffId,
    role: 'staff',
    supervisorStaffId,
  }).select('staffId');
  return Boolean(member);
}

function parseYearMonth(year, month) {
  const y = parseInt(year, 10);
  const m = parseInt(month, 10);
  if (Number.isNaN(y) || Number.isNaN(m) || m < 1 || m > 12) {
    return { ok: false, message: 'Invalid year or month' };
  }
  return { ok: true, year: y, month: m };
}

async function getPdfForStaff(staffId, year, month) {
  const record = await PayslipRecord.findOne({ staffId, year, month }).lean();
  if (!record?.pdfFile) {
    return { ok: false, status: 404, message: 'No PDF payslip for this period' };
  }
  return {
    ok: true,
    data: {
      staffId,
      year,
      month,
      pdfFile: record.pdfFile,
      pdfFileName: record.pdfFileName || `payslip-${staffId}-${year}-${month}.pdf`,
      pdfSource: record.pdfSource || '',
      hasPdf: true,
    },
  };
}

exports.uploadPayslipPdf = async (req, res) => {
  try {
    const { staffId, year, month, pdfFile, pdfFileName, netPay, grossPay, remarks } = req.body;
    if (!staffId || year == null || month == null) {
      return res.status(400).json({ success: false, message: 'staffId, year, month required' });
    }
    const parsed = parseYearMonth(year, month);
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const pdfCheck = validatePayslipPdf(pdfFile);
    if (!pdfCheck.ok) return res.status(400).json({ success: false, message: pdfCheck.message });

    const user = await findPayrollUser(staffId);
    if (!user) return res.status(404).json({ success: false, message: 'Staff or supervisor not found' });

    const net = netPay != null ? Number(netPay) : null;
    const gross = grossPay != null ? Number(grossPay) : Number(user.salary) || 0;
    if (net == null || Number.isNaN(net)) {
      return res.status(400).json({ success: false, message: 'netPay required for upload' });
    }

    const doc = await PayslipRecord.findOneAndUpdate(
      { staffId, year: parsed.year, month: parsed.month },
      {
        $set: {
          netPay: net,
          grossPay: gross,
          remarks: remarks || '',
          issuedBy: 'admin',
          pdfFile: pdfCheck.value,
          pdfFileName: pdfFileName || `payslip-${staffId}-${parsed.year}-${parsed.month}.pdf`,
          pdfSource: 'upload',
        },
      },
      { upsert: true, new: true },
    );

    res.json({
      success: true,
      message: 'Payslip PDF uploaded',
      data: sanitizePayslipRecord(doc),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.generatePayslipPdf = async (req, res) => {
  try {
    const { staffId, year, month } = req.body;
    if (!staffId || year == null || month == null) {
      return res.status(400).json({ success: false, message: 'staffId, year, month required' });
    }
    const parsed = parseYearMonth(year, month);
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const user = await findPayrollUser(staffId);
    if (!user) return res.status(404).json({ success: false, message: 'Staff or supervisor not found' });

    const payslip = await buildPayslipData(staffId, parsed.year, parsed.month);
    if (!payslip.ok) {
      return res.status(payslip.status || 400).json({ success: false, message: payslip.message });
    }

    const buffer = await generatePayslipPdfBuffer(payslip.data);
    const pdfFile = bufferToPdfDataUrl(buffer);
    const pdfFileName = `payslip-${staffId}-${parsed.year}-${parsed.month}.pdf`;

    const doc = await PayslipRecord.findOneAndUpdate(
      { staffId, year: parsed.year, month: parsed.month },
      {
        $set: {
          netPay: payslip.data.netPay,
          grossPay: payslip.data.earnings?.grossSalary ?? 0,
          remarks: payslip.data.adminRemarks || '',
          issuedBy: 'admin',
          pdfFile,
          pdfFileName,
          pdfSource: 'generated',
        },
      },
      { upsert: true, new: true },
    );

    res.json({
      success: true,
      message: 'Payslip PDF generated',
      data: sanitizePayslipRecord(doc),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAdminPayslipPdf = async (req, res) => {
  try {
    const { staffId } = req.params;
    const parsed = parseYearMonth(req.query.year, req.query.month);
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const result = await getPdfForStaff(staffId, parsed.year, parsed.month);
    if (!result.ok) return res.status(result.status || 404).json({ success: false, message: result.message });
    res.json({ success: true, data: result.data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getStaffPayslipPdf = async (req, res) => {
  try {
    const { staffId } = req.params;
    if (req.user.staffId !== staffId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'You can only view your own payslip PDF' });
    }
    const parsed = parseYearMonth(
      req.query.year ?? new Date().getFullYear(),
      req.query.month ?? new Date().getMonth() + 1,
    );
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const result = await getPdfForStaff(staffId, parsed.year, parsed.month);
    if (!result.ok) return res.status(result.status || 404).json({ success: false, message: result.message });
    res.json({ success: true, data: result.data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getSupervisorStaffPayslip = async (req, res) => {
  try {
    const { staffId } = req.params;
    const allowed = await assertSupervisorCanView(req.user.staffId, staffId);
    if (!allowed) {
      return res.status(403).json({ success: false, message: 'Not authorized to view this payslip' });
    }
    const parsed = parseYearMonth(
      req.query.year ?? new Date().getFullYear(),
      req.query.month ?? new Date().getMonth() + 1,
    );
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const payslip = await buildPayslipData(staffId, parsed.year, parsed.month);
    if (!payslip.ok) {
      return res.status(payslip.status || 400).json({ success: false, message: payslip.message });
    }
    res.json({ success: true, data: payslip.data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getSupervisorStaffPayslipPdf = async (req, res) => {
  try {
    const { staffId } = req.params;
    const allowed = await assertSupervisorCanView(req.user.staffId, staffId);
    if (!allowed) {
      return res.status(403).json({ success: false, message: 'Not authorized to view this payslip PDF' });
    }
    const parsed = parseYearMonth(
      req.query.year ?? new Date().getFullYear(),
      req.query.month ?? new Date().getMonth() + 1,
    );
    if (!parsed.ok) return res.status(400).json({ success: false, message: parsed.message });

    const result = await getPdfForStaff(staffId, parsed.year, parsed.month);
    if (!result.ok) return res.status(result.status || 404).json({ success: false, message: result.message });
    res.json({ success: true, data: result.data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getSupervisorTeamPayslipRecords = async (req, res) => {
  try {
    const team = await User.find({ role: 'staff', supervisorStaffId: req.user.staffId })
      .select('staffId name')
      .lean();
    const ids = team.map((t) => t.staffId);
    if (ids.length === 0) {
      return res.json({ success: true, data: [] });
    }
    const filter = { staffId: { $in: ids } };
    if (req.query.year) filter.year = parseInt(req.query.year, 10);
    if (req.query.month) filter.month = parseInt(req.query.month, 10);
    const list = await PayslipRecord.find(filter).sort({ year: -1, month: -1 }).limit(200).lean();
    const nameMap = Object.fromEntries(team.map((t) => [t.staffId, t.name]));
    res.json({
      success: true,
      data: list.map((r) => ({ ...sanitizePayslipRecord(r), staffName: nameMap[r.staffId] || r.staffId })),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
