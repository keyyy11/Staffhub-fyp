function validatePayslipPdf(pdfFile) {
  if (!pdfFile || typeof pdfFile !== 'string') {
    return { ok: false, message: 'PDF file is required' };
  }
  const trimmed = pdfFile.trim();
  if (!/^data:application\/pdf;base64,/i.test(trimmed)) {
    return { ok: false, message: 'Payslip must be a PDF file (application/pdf)' };
  }
  const base64Part = trimmed.split(',')[1] || '';
  const approxBytes = (base64Part.length * 3) / 4;
  const maxMb = process.env.VERCEL ? 3 : 4;
  if (approxBytes > maxMb * 1024 * 1024) {
    return { ok: false, message: `PDF is too large (maximum ${maxMb}MB)` };
  }
  return { ok: true, value: trimmed };
}

module.exports = { validatePayslipPdf };
