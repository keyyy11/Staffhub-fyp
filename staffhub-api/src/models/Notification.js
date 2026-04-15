const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: {
      type: String,
      enum: ['clock_in', 'clock_out', 'ot_request'],
      required: true,
    },
    /** Optional link for OT notifications (OvertimeRequest _id). */
    relatedId: { type: mongoose.Schema.Types.ObjectId, ref: 'OvertimeRequest', default: null },
    staffId: { type: String, required: true },
    staffName: { type: String, default: '' },
    read: { type: Boolean, default: false },
  },
  { timestamps: true },
);

notificationSchema.index({ recipientId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
