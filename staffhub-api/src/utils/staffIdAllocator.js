const User = require('../models/User');

const AUTO_STAFF_PREFIX = 'STF';
const AUTO_SUPERVISOR_PREFIX = 'SUP';

/**
 * Next numeric suffix for IDs like STF007 / SUP003. Scans existing User.staffId values.
 */
async function allocateNextId(prefix) {
  const re = new RegExp(`^${prefix}(\\d{1,8})$`, 'i');
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const users = await User.find({ staffId: re }).select('staffId').lean();
    let max = 0;
    for (const u of users) {
      const m = String(u.staffId).match(re);
      if (m) {
        const n = parseInt(m[1], 10);
        if (!Number.isNaN(n) && n > max) max = n;
      }
    }
    const nextNum = max + 1 + attempt;
    const candidate = `${prefix}${String(nextNum).padStart(3, '0')}`;
    const taken = await User.findOne({ staffId: candidate });
    if (!taken) return candidate;
  }
  throw new Error('Could not allocate a unique staff ID');
}

module.exports = {
  allocateNextId,
  AUTO_STAFF_PREFIX,
  AUTO_SUPERVISOR_PREFIX,
};
