const mongoose = require('mongoose');

const flowEntrySchema = new mongoose.Schema(
  {
    at: { type: Date, default: Date.now },
    action: { type: String, enum: ['submitted', 'approved', 'rejected'], required: true },
    actorStaffId: { type: String, default: '' },
    actorRole: { type: String, default: '' },
    note: { type: String, default: '', trim: true },
  },
  { _id: false },
);

const overtimeRequestSchema = new mongoose.Schema(
  {
    staffId: { type: String, required: true, index: true },
    staffName: { type: String, default: '' },
    /** Supervisor Staff ID at time of application (who should approve). */
    supervisorStaffIdAtSubmit: { type: String, default: '', index: true },
    otDate: { type: Date, required: true },
    hours: { type: Number, required: true, min: 0.5, max: 24 },
    reason: { type: String, default: '', trim: true },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    approverStaffId: { type: String, default: '' },
    approverName: { type: String, default: '' },
    approverComment: { type: String, default: '', trim: true },
    decidedAt: { type: Date, default: null },
    flow: { type: [flowEntrySchema], default: [] },
  },
  { timestamps: true },
);

overtimeRequestSchema.index({ staffId: 1, createdAt: -1 });
overtimeRequestSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('OvertimeRequest', overtimeRequestSchema);
