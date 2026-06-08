const Branch = require('../models/Branch');
const User = require('../models/User');
const workplace = require('../config/workplace');

const BRANCH_CODE_RE = /^[A-Z0-9_-]{2,16}$/;

async function ensureDefaultBranch() {
  const count = await Branch.countDocuments();
  if (count > 0) return;
  await Branch.create({
    branchCode: 'HQ',
    name: 'Cawangan Utama (HQ)',
    address: '',
    lat: workplace.lat,
    lng: workplace.lng,
    radiusMeters: workplace.radiusMeters,
    isActive: true,
  });
}

function parseCoords(body) {
  const lat = parseFloat(body.lat);
  const lng = parseFloat(body.lng);
  if (Number.isNaN(lat) || Number.isNaN(lng)) {
    return { error: 'Valid lat and lng are required' };
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return { error: 'lat/lng out of valid range' };
  }
  let radiusMeters = body.radiusMeters != null ? parseInt(body.radiusMeters, 10) : 60;
  if (Number.isNaN(radiusMeters)) radiusMeters = 60;
  radiusMeters = Math.min(5000, Math.max(10, radiusMeters));
  return { lat, lng, radiusMeters };
}

exports.listBranches = async (req, res) => {
  try {
    await ensureDefaultBranch();
    const branches = await Branch.find().sort({ branchCode: 1 }).lean();
    res.json({ success: true, data: branches });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createBranch = async (req, res) => {
  try {
    const branchCode = String(req.body.branchCode || '').trim().toUpperCase();
    const name = String(req.body.name || '').trim();
    const address = String(req.body.address || '').trim();
    const isActive = req.body.isActive !== false;

    if (!BRANCH_CODE_RE.test(branchCode)) {
      return res.status(400).json({
        success: false,
        message: 'Branch code must be 2–16 characters (letters, numbers, _ or -)',
      });
    }
    if (!name) {
      return res.status(400).json({ success: false, message: 'Branch name is required' });
    }

    const coords = parseCoords(req.body);
    if (coords.error) {
      return res.status(400).json({ success: false, message: coords.error });
    }

    const existing = await Branch.findOne({ branchCode });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Branch code already exists' });
    }

    const branch = await Branch.create({
      branchCode,
      name,
      address,
      lat: coords.lat,
      lng: coords.lng,
      radiusMeters: coords.radiusMeters,
      isActive,
    });

    res.status(201).json({ success: true, message: 'Branch created', data: branch });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBranch = async (req, res) => {
  try {
    const { branchCode: paramCode } = req.params;
    const branch = await Branch.findOne({ branchCode: String(paramCode).trim().toUpperCase() });
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    if (req.body.name !== undefined) {
      const name = String(req.body.name).trim();
      if (!name) {
        return res.status(400).json({ success: false, message: 'Branch name cannot be empty' });
      }
      branch.name = name;
    }
    if (req.body.address !== undefined) branch.address = String(req.body.address).trim();
    if (req.body.isActive !== undefined) branch.isActive = Boolean(req.body.isActive);

    if (req.body.lat !== undefined || req.body.lng !== undefined) {
      const coords = parseCoords({
        lat: req.body.lat ?? branch.lat,
        lng: req.body.lng ?? branch.lng,
        radiusMeters: req.body.radiusMeters ?? branch.radiusMeters,
      });
      if (coords.error) {
        return res.status(400).json({ success: false, message: coords.error });
      }
      branch.lat = coords.lat;
      branch.lng = coords.lng;
      branch.radiusMeters = coords.radiusMeters;
    } else if (req.body.radiusMeters !== undefined) {
      let radiusMeters = parseInt(req.body.radiusMeters, 10);
      if (Number.isNaN(radiusMeters)) radiusMeters = branch.radiusMeters;
      branch.radiusMeters = Math.min(5000, Math.max(10, radiusMeters));
    }

    await branch.save();
    res.json({ success: true, message: 'Branch updated', data: branch });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteBranch = async (req, res) => {
  try {
    const code = String(req.params.branchCode).trim().toUpperCase();
    const branch = await Branch.findOne({ branchCode: code });
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    const assigned = await User.countDocuments({ branchCode: code });
    if (assigned > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete: ${assigned} staff still assigned to this branch. Reassign them first or deactivate the branch.`,
      });
    }

    await Branch.deleteOne({ branchCode: code });
    res.json({ success: true, message: 'Branch deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
