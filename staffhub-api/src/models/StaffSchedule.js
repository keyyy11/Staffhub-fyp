const mongoose = require('mongoose');

const daySchema = new mongoose.Schema(
  {
    day: { type: String, required: true },
    isWorkingDay: { type: Boolean, default: true },
    workStart: { type: String, default: '09:00' },
    workEnd: { type: String, default: '18:00' },
  },
  { _id: false },
);

const staffScheduleSchema = new mongoose.Schema(
  {
    staffId: { type: String, required: true, unique: true, index: true },
    days: { type: [daySchema], default: [] },
    notes: { type: String, default: '' },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('StaffSchedule', staffScheduleSchema);
