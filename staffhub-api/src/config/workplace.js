module.exports = {
  lat: parseFloat(process.env.WORKPLACE_LAT) || 1.5589,
  lng: parseFloat(process.env.WORKPLACE_LNG) || 103.6391,
  radiusMeters: parseInt(process.env.WORKPLACE_RADIUS_METERS, 10) || 60,
  expectedClockInHour: parseInt(process.env.EXPECTED_CLOCK_IN_HOUR, 10) || 9,
  expectedClockInMinute: parseInt(process.env.EXPECTED_CLOCK_IN_MINUTE, 10) || 0,
  /** Waktu kerja standard (untuk paparan jadual) */
  workStartHour: parseInt(process.env.WORK_START_HOUR, 10) || 9,
  workStartMinute: parseInt(process.env.WORK_START_MINUTE, 10) || 0,
  workEndHour: parseInt(process.env.WORK_END_HOUR, 10) || 18,
  workEndMinute: parseInt(process.env.WORK_END_MINUTE, 10) || 0,
  breakMinutes: parseInt(process.env.BREAK_MINUTES, 10) || 60,
};
