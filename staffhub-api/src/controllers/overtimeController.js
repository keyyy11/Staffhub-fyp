const User = require('../models/User');
const OvertimeRequest = require('../models/OvertimeRequest');
const Notification = require('../models/Notification');

async function getTeamStaffIds(supervisorStaffId) {
  const team = await User.find({ role: 'staff', supervisorStaffId }).select('staffId').lean();
  return team.map((t) => t.staffId);
}

async function notifySupervisorNewOt(supervisorStaffId, staffUser, overtimeDoc) {
  if (!supervisorStaffId) return;
  const sup = await User.findOne({ staffId: supervisorStaffId, role: 'supervisor' });
  if (!sup) return;
  await Notification.create({
    recipientId: sup._id,
    type: 'ot_request',
    staffId: staffUser.staffId,
    staffName: staffUser.name || '',
    relatedId: overtimeDoc._id,
    read: false,
  });
}

exports.applyOvertime = async (req, res) => {
  try {
    const u = req.user;
    const { otDate, hours, reason } = req.body;
    if (!otDate) {
      return res.status(400).json({ success: false, message: 'otDate is required' });
    }
    const h = Number(hours);
    if (Number.isNaN(h) || h < 0.5 || h > 24) {
      return res.status(400).json({ success: false, message: 'hours must be between 0.5 and 24' });
    }
    const supId = (u.supervisorStaffId && String(u.supervisorStaffId).trim()) || '';
    const doc = await OvertimeRequest.create({
      staffId: u.staffId,
      staffName: u.name || '',
      supervisorStaffIdAtSubmit: supId,
      otDate: new Date(otDate),
      hours: h,
      reason: reason != null ? String(reason).trim() : '',
      status: 'pending',
      flow: [
        {
          at: new Date(),
          action: 'submitted',
          actorStaffId: u.staffId,
          actorRole: 'staff',
          note: '',
        },
      ],
    });
    await notifySupervisorNewOt(supId, u, doc);
    res.status(201).json({ success: true, message: 'Overtime request submitted', data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getMyOvertimeRequests = async (req, res) => {
  try {
    const list = await OvertimeRequest.find({ staffId: req.user.staffId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json({ success: true, data: list });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getTeamOvertimeRequests = async (req, res) => {
  try {
    const teamIds = await getTeamStaffIds(req.user.staffId);
    if (teamIds.length === 0) {
      return res.json({ success: true, data: [] });
    }
    const { status } = req.query;
    const filter = { staffId: { $in: teamIds } };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      filter.status = status;
    }
    const requests = await OvertimeRequest.find(filter).sort({ createdAt: -1 }).limit(200).lean();
    const nameMap = Object.fromEntries(
      (await User.find({ staffId: { $in: teamIds } }).select('staffId name').lean()).map((x) => [x.staffId, x.name]),
    );
    const data = requests.map((r) => ({
      ...r,
      staffName: nameMap[r.staffId] || r.staffName || r.staffId,
    }));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.supervisorDecideOvertime = async (req, res) => {
  try {
    const teamIds = await getTeamStaffIds(req.user.staffId);
    const { id } = req.params;
    const { status, comment } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be approved or rejected' });
    }
    const doc = await OvertimeRequest.findById(id);
    if (!doc) {
      return res.status(404).json({ success: false, message: 'Overtime request not found' });
    }
    if (!teamIds.includes(doc.staffId)) {
      return res.status(403).json({ success: false, message: 'Not your team member' });
    }
    if (doc.status !== 'pending') {
      return res.status(400).json({ success: false, message: 'Request already processed' });
    }
    doc.status = status;
    doc.approverStaffId = req.user.staffId;
    doc.approverName = req.user.name || '';
    doc.approverComment = comment != null ? String(comment).trim() : '';
    doc.decidedAt = new Date();
    doc.flow.push({
      at: new Date(),
      action: status,
      actorStaffId: req.user.staffId,
      actorRole: 'supervisor',
      note: doc.approverComment,
    });
    await doc.save();
    res.json({ success: true, message: `Overtime ${status}`, data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** All OT requests for organisation staff/supervisors (admin excluded). Supervisor home overview. */
exports.getOrgOvertimeRequests = async (req, res) => {
  try {
    const orgUsers = await User.find({ role: { $in: ['staff', 'supervisor'] } }).select('staffId').lean();
    const ids = orgUsers.map((u) => u.staffId);
    if (ids.length === 0) {
      return res.json({ success: true, data: [] });
    }
    const { status } = req.query;
    const filter = { staffId: { $in: ids } };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      filter.status = status;
    }
    const requests = await OvertimeRequest.find(filter).sort({ createdAt: -1 }).limit(300).lean();
    const nameMap = Object.fromEntries(
      (await User.find({ staffId: { $in: ids } }).select('staffId name').lean()).map((x) => [x.staffId, x.name]),
    );
    const data = requests.map((r) => ({
      ...r,
      staffName: nameMap[r.staffId] || r.staffName || r.staffId,
    }));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAllOvertimeRequests = async (req, res) => {
  try {
    const { status, staffId } = req.query;
    const filter = {};
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      filter.status = status;
    }
    if (staffId) {
      filter.staffId = String(staffId).trim();
    }
    const requests = await OvertimeRequest.find(filter).sort({ createdAt: -1 }).limit(300).lean();
    const ids = [...new Set(requests.map((r) => r.staffId))];
    const users = await User.find({ staffId: { $in: ids } }).select('staffId name').lean();
    const nameMap = Object.fromEntries(users.map((x) => [x.staffId, x.name]));
    const supIds = [...new Set(requests.map((r) => r.supervisorStaffIdAtSubmit).filter((id) => id && String(id).trim()))];
    const supUsers = await User.find({ staffId: { $in: supIds }, role: 'supervisor' }).select('staffId name').lean();
    const supNameMap = Object.fromEntries(supUsers.map((s) => [s.staffId, s.name]));
    const data = requests.map((r) => {
      const sid = r.supervisorStaffIdAtSubmit ? String(r.supervisorStaffIdAtSubmit).trim() : '';
      return {
        ...r,
        staffName: nameMap[r.staffId] || r.staffName || r.staffId,
        supervisorNameAtSubmit: sid ? supNameMap[sid] || sid : '',
      };
    });
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
