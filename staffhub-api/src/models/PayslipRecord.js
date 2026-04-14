const mongoose = require('mongoose');

/** Slip gaji yang admin sahkan / masukkan untuk staff mengikut bulan */
const payslipRecordSchema = new mongoose.Schema(
  {
    staffId: { type: String, required: true, index: true },
    year: { type: Number, required: true },
    month: { type: Number, required: true, min: 1, max: 12 },
    grossPay: { type: Number, default: 0 },
    netPay: { type: Number, required: true },
    remarks: { type: String, default: '' },
    issuedBy: { type: String, default: 'admin' },
  },
  { timestamps: true },
);

payslipRecordSchema.index({ staffId: 1, year: 1, month: 1 }, { unique: true });

module.exports = mongoose.model('PayslipRecord', payslipRecordSchema);
