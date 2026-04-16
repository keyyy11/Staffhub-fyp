const mongoose = require('mongoose');

const daySchema = new mongoose.Schema(
  {
    day: { type: String, required: true },
    /** morning | afternoon | off — jika ada, digunakan untuk masa shift tetap. */
    shiftType: { type: String, enum: ['morning', 'afternoon', 'off'] },
    /** false = hari cuti / rehat. Tiada `default: true` — nilai lama true senyap menyebabkan semua hari nampak kerja. */
    isWorkingDay: { type: Boolean },
    workStart: { type: String, default: '09:00' },
    workEnd: { type: String, default: '18:00' },
  },
  { _id: false },
);

const dateEntrySchema = new mongoose.Schema(
  {
    date: { type: String, required: true },
    shiftType: { type: String, enum: ['morning', 'afternoon', 'off'] },
    isWorkingDay: { type: Boolean },
    workStart: { type: String },
    workEnd: { type: String },
  },
  { _id: false },
);

const staffScheduleSchema = new mongoose.Schema(
  {
    staffId: { type: String, required: true, unique: true, index: true },
    /** Lalai mingguan (Isnin–Ahad) — dipakai jika tiada rekod dalam [dateEntries] untuk tarikh itu. */
    days: { type: [daySchema], default: [] },
    /** Override ikut tarikh (YYYY-MM-DD) — Isnin minggu ini cuti, Isnin minggu depan petang. */
    dateEntries: { type: [dateEntrySchema], default: [] },
    notes: { type: String, default: '' },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('StaffSchedule', staffScheduleSchema);
