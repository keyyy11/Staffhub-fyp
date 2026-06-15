const AccessLog = require('../models/AccessLog');

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  if (Array.isArray(forwarded) && forwarded[0]) {
    return String(forwarded[0]).trim();
  }
  return req.socket?.remoteAddress || req.ip || '';
}

function normalizePlatform(raw) {
  const p = String(raw || '').toLowerCase().trim();
  if (p === 'cms' || p === 'mobile') return p;
  return 'unknown';
}

/**
 * Record admin access (login / logout / failed login).
 * @param {object} opts
 * @param {object|null} opts.user - User doc or { staffId, name, email, role }
 * @param {string} opts.action
 * @param {string} [opts.platform]
 * @param {import('express').Request} opts.req
 * @param {boolean} [opts.success]
 */
async function recordAdminAccessLog({ user, action, platform, req, success = true }) {
  if (!user || user.role !== 'admin') return;

  try {
    await AccessLog.create({
      staffId: user.staffId || '',
      name: user.name || '',
      email: user.email || '',
      role: 'admin',
      action,
      platform: normalizePlatform(platform),
      ipAddress: clientIp(req),
      userAgent: String(req.headers['user-agent'] || '').slice(0, 512),
      success: success === true,
    });
  } catch (err) {
    console.warn('[AccessLog] failed to record:', err.message);
  }
}

module.exports = { recordAdminAccessLog, clientIp, normalizePlatform };
