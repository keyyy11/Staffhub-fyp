const User = require('../models/User');
const { computeStaffPerformance } = require('../utils/staffPerformance');

exports.getStaffPerformanceAdmin = async (req, res) => {
  try {
    const { staffId } = req.params;
    const days = req.query.days;
    const data = await computeStaffPerformance(staffId, days);
    if (!data) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getStaffPerformanceSupervisor = async (req, res) => {
  try {
    const { staffId } = req.params;
    const supervisorId = req.user?.staffId;
    const member = await User.findOne({ staffId: String(staffId).trim(), role: 'staff' })
      .select('staffId supervisorStaffId')
      .lean();

    if (!member) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    if (member.supervisorStaffId !== supervisorId) {
      return res.status(403).json({
        success: false,
        message: 'You can only view performance for your direct reports',
      });
    }

    const data = await computeStaffPerformance(staffId, req.query.days);
    if (!data) {
      return res.status(404).json({ success: false, message: 'Staff not found' });
    }
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getPerformanceOverviewAdmin = async (req, res) => {
  try {
    const days = req.query.days;
    const staffRows = await User.find({ role: { $in: ['staff', 'supervisor'] } })
      .select('staffId name role')
      .sort({ name: 1 })
      .lean();

    const results = await Promise.all(
      staffRows.map(async (s) => {
        const perf = await computeStaffPerformance(s.staffId, days);
        if (!perf) return null;
        return {
          staffId: perf.staffId,
          staffName: perf.staffName,
          role: perf.role,
          performanceScore: perf.performanceScore,
          performanceGrade: perf.performanceGrade,
          attendance: perf.attendance,
        };
      }),
    );

    const staff = results.filter(Boolean).sort((a, b) => b.performanceScore - a.performanceScore);
    const periodDays = Math.min(Math.max(parseInt(days, 10) || 90, 7), 365);

    res.json({ success: true, data: { periodDays, staff } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
