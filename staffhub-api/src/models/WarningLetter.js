const mongoose = require('mongoose');

const warningLetterSchema = new mongoose.Schema(
  {
    staffId: { type: String, required: true, index: true },
    staffName: { type: String, default: '' },
    category: {
      type: String,
      required: true,
      enum: ['late_five_times', 'attendance_leave_unsatisfactory', 'other'],
    },
    notes: { type: String, required: true, trim: true },
    issuedByAdminId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    issuedByName: { type: String, default: '' },
    issuedByEmail: { type: String, default: '' },
  },
  { timestamps: true },
);

warningLetterSchema.index({ staffId: 1, createdAt: -1 });

module.exports = mongoose.model('WarningLetter', warningLetterSchema);
