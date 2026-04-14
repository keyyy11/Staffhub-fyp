const mongoose = require('mongoose');

const leaveBalanceSchema = new mongoose.Schema({
  staffId: {
    type: String,
    required: true,
    index: true,
  },
  year: {
    type: Number,
    required: true,
    default: () => new Date().getFullYear(),
  },
  medicalLeave: {
    total: { type: Number, default: 14 },
    used: { type: Number, default: 0 },
  },
  annualLeave: {
    total: { type: Number, default: 14 },
    used: { type: Number, default: 0 },
  },
  unpaidLeave: {
    total: { type: Number, default: 0 },
    used: { type: Number, default: 0 },
  },
  otherLeave: {
    total: { type: Number, default: 5 },
    used: { type: Number, default: 0 },
  },
}, {
  timestamps: true,
});

leaveBalanceSchema.index({ staffId: 1, year: 1 }, { unique: true });

leaveBalanceSchema.virtual('medicalLeave.remaining').get(function () {
  return Math.max(0, this.medicalLeave.total - this.medicalLeave.used);
});

module.exports = mongoose.model('LeaveBalance', leaveBalanceSchema);
