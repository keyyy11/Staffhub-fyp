const mongoose = require('mongoose');

const accessLogSchema = new mongoose.Schema(
  {
    staffId: { type: String, default: '', index: true },
    name: { type: String, default: '' },
    email: { type: String, default: '', index: true },
    role: { type: String, default: 'admin' },
    action: {
      type: String,
      enum: ['login', 'logout', 'login_failed'],
      required: true,
      index: true,
    },
    platform: {
      type: String,
      enum: ['cms', 'mobile', 'unknown'],
      default: 'unknown',
      index: true,
    },
    ipAddress: { type: String, default: '' },
    userAgent: { type: String, default: '' },
    success: { type: Boolean, default: true },
  },
  { timestamps: true },
);

accessLogSchema.index({ createdAt: -1 });
accessLogSchema.index({ role: 1, createdAt: -1 });

module.exports = mongoose.model('AccessLog', accessLogSchema);
