const User = require('../models/User');
const Branch = require('../models/Branch');
const workplace = require('../config/workplace');

function defaultWorkplace() {
  return {
    lat: workplace.lat,
    lng: workplace.lng,
    radiusMeters: workplace.radiusMeters,
    branchCode: '',
    branchName: 'Default workplace',
    address: '',
  };
}

/** Resolve geofence circle for a staff member (branch assignment or global default). */
async function resolveWorkplaceForStaff(staffId) {
  if (!staffId) return defaultWorkplace();

  const user = await User.findOne({ staffId }).select('branchCode').lean();
  const code = user?.branchCode?.trim();
  if (!code) return defaultWorkplace();

  const branch = await Branch.findOne({ branchCode: code.toUpperCase(), isActive: true }).lean();
  if (!branch) return defaultWorkplace();

  return {
    lat: branch.lat,
    lng: branch.lng,
    radiusMeters: branch.radiusMeters,
    branchCode: branch.branchCode,
    branchName: branch.name,
    address: branch.address || '',
  };
}

module.exports = { resolveWorkplaceForStaff, defaultWorkplace };
