const mongoose = require('mongoose');

const branchSchema = new mongoose.Schema({
  branchCode: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    uppercase: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  address: { type: String, default: '', trim: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  radiusMeters: { type: Number, default: 60, min: 10, max: 5000 },
  isActive: { type: Boolean, default: true },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Branch', branchSchema);
