const mongoose = require('mongoose');

const leaveRequestSchema = new mongoose.Schema({
  staffId: {
    type: String,
    required: true,
    index: true,
  },
  leaveType: {
    type: String,
    required: true,
    enum: ['medical', 'annual', 'unpaid', 'other'],
  },
  startDate: {
    type: Date,
    required: true,
  },
  endDate: {
    type: Date,
    required: true,
  },
  totalDays: {
    type: Number,
    required: true,
  },
  reason: {
    type: String,
    default: '',
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
  },
  /** Optional note from admin when approving or rejecting (shown to staff). */
  adminComment: {
    type: String,
    default: '',
    trim: true,
  },
}, {
  timestamps: true,
});

leaveRequestSchema.index({ staffId: 1, createdAt: -1 });

module.exports = mongoose.model('LeaveRequest', leaveRequestSchema);
