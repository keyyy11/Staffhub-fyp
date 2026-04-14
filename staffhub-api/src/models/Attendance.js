const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  staffId: {
    type: String,
    required: true,
    index: true,
  },
  date: {
    type: Date,
    required: true,
    default: () => new Date().setHours(0, 0, 0, 0),
  },
  clockIn: {
    type: Date,
    required: true,
  },
  clockOut: {
    type: Date,
    default: null,
  },
  clockInLocation: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
  },
  clockOutLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
}, {
  timestamps: true,
});

attendanceSchema.index({ staffId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('Attendance', attendanceSchema);
