const AccessLog = require('../models/AccessLog');
const { recordAdminAccessLog } = require('../utils/accessLog');

exports.logout = async (req, res) => {
  try {
    const platform = req.body?.platform;
    await recordAdminAccessLog({
      user: req.user,
      action: 'logout',
      platform,
      req,
      success: true,
    });
    res.json({ success: true, message: 'Logged out' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAdminAccessLogs = async (req, res) => {
  try {
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 365);
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 100, 1), 500);
    const action = req.query.action;
    const platform = req.query.platform;

    const start = new Date();
    start.setDate(start.getDate() - days);
    start.setHours(0, 0, 0, 0);

    const filter = { role: 'admin', createdAt: { $gte: start } };
    if (action && ['login', 'logout', 'login_failed'].includes(action)) {
      filter.action = action;
    }
    if (platform && ['cms', 'mobile', 'unknown'].includes(platform)) {
      filter.platform = platform;
    }

    const logs = await AccessLog.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    res.json({
      success: true,
      data: {
        periodDays: days,
        total: logs.length,
        logs,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
