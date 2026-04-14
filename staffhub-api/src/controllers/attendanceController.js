const Attendance = require('../models/Attendance');
const { isWithinRadius } = require('../utils/distance');
const workplace = require('../config/workplace');

// Clock In - Hadir
exports.clockIn = async (req, res) => {
  try {
    const { staffId, lat, lng } = req.body;

    if (!staffId || lat === undefined || lng === undefined) {
      return res.status(400).json({
        success: false,
        message: 'staffId, lat and lng are required',
      });
    }

    if (!isWithinRadius(lat, lng, workplace.lat, workplace.lng, workplace.radiusMeters)) {
      return res.status(403).json({
        success: false,
        message: `You are outside the ${workplace.radiusMeters}m radius from workplace. Please move closer.`,
      });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const existing = await Attendance.findOne({ staffId, date: today });
    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'You have already clocked in today',
      });
    }

    const attendance = await Attendance.create({
      staffId,
      date: today,
      clockIn: new Date(),
      clockInLocation: { lat, lng },
    });

    res.status(201).json({
      success: true,
      message: 'Clock in successful',
      data: attendance,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Clock Out - Pulang
exports.clockOut = async (req, res) => {
  try {
    const { staffId, lat, lng } = req.body;

    if (!staffId || lat === undefined || lng === undefined) {
      return res.status(400).json({
        success: false,
        message: 'staffId, lat and lng are required',
      });
    }

    if (!isWithinRadius(lat, lng, workplace.lat, workplace.lng, workplace.radiusMeters)) {
      return res.status(403).json({
        success: false,
        message: `You are outside the ${workplace.radiusMeters}m radius from workplace. Please move closer.`,
      });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const attendance = await Attendance.findOne({ staffId, date: today });

    if (!attendance) {
      return res.status(400).json({
        success: false,
        message: 'No clock in record today. Please clock in first.',
      });
    }

    if (attendance.clockOut) {
      return res.status(400).json({
        success: false,
        message: 'You have already clocked out today',
      });
    }

    attendance.clockOut = new Date();
    attendance.clockOutLocation = { lat, lng };
    await attendance.save();

    res.json({
      success: true,
      message: 'Clock out successful',
      data: attendance,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get today's attendance for a staff
exports.getTodayAttendance = async (req, res) => {
  try {
    const { staffId } = req.params;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const record = await Attendance.findOne({ staffId, date: today }).lean();

    res.json({
      success: true,
      data: record,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Auto clock out after 12 hours (no location required)
const MAX_WORK_HOURS = 12;

exports.autoClockOut = async (req, res) => {
  try {
    const { staffId } = req.body;

    if (!staffId) {
      return res.status(400).json({
        success: false,
        message: 'staffId is required',
      });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const attendance = await Attendance.findOne({ staffId, date: today });

    if (!attendance) {
      return res.status(400).json({
        success: false,
        message: 'No clock in record today',
      });
    }

    if (attendance.clockOut) {
      return res.status(400).json({
        success: false,
        message: 'Already clocked out today',
      });
    }

    const elapsedMs = Date.now() - attendance.clockIn.getTime();
    const elapsedHours = elapsedMs / (1000 * 60 * 60);

    if (elapsedHours < MAX_WORK_HOURS) {
      return res.status(400).json({
        success: false,
        message: `Must work at least ${MAX_WORK_HOURS} hours before auto clock out. Elapsed: ${elapsedHours.toFixed(1)}h`,
      });
    }

    attendance.clockOut = new Date();
    attendance.clockOutLocation = attendance.clockInLocation;
    await attendance.save();

    res.json({
      success: true,
      message: 'Auto clock out successful (12h limit reached)',
      data: attendance,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get attendance records for a staff
exports.getMyAttendance = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { limit = 30 } = req.query;

    const records = await Attendance.find({ staffId })
      .sort({ date: -1 })
      .limit(parseInt(limit, 10))
      .lean();

    res.json({
      success: true,
      data: records,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get workplace info (for app to show radius/distance)
exports.getWorkplaceInfo = (req, res) => {
  res.json({
    success: true,
    data: {
      lat: workplace.lat,
      lng: workplace.lng,
      radiusMeters: workplace.radiusMeters,
    },
  });
};
