const User = require('../models/User');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { allocateNextId, AUTO_STAFF_PREFIX, AUTO_SUPERVISOR_PREFIX } = require('../utils/staffIdAllocator');
const { isEmailConfigured, sendPasswordResetEmail } = require('../services/emailService');
const { recordAdminAccessLog } = require('../utils/accessLog');

const JWT_SECRET = process.env.JWT_SECRET || 'staffhub-secret-key-change-in-production';

function generateToken(user) {
  return jwt.sign(
    { userId: user._id, staffId: user.staffId },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
}

function hashResetCode(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

function generateResetCode() {
  return String(crypto.randomInt(100000, 999999));
}

function resetExpiryMinutes() {
  const n = parseInt(process.env.RESET_CODE_EXPIRY_MINUTES || '15', 10);
  return Number.isFinite(n) && n > 0 ? n : 15;
}

exports.register = async (req, res) => {
  try {
    const { name, email, password, autoStaffId } = req.body;
    let staffId = req.body.staffId != null ? String(req.body.staffId).trim() : '';
    const useAutoStaffId = autoStaffId === true || !staffId || staffId.toLowerCase() === 'auto';

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, email, and password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    if (useAutoStaffId) {
      staffId = await allocateNextId(AUTO_STAFF_PREFIX);
    }

    if (!staffId || staffId.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID is required, or enable automatic ID (autoStaffId / leave staffId empty)',
      });
    }

    if (staffId.length > 64) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID must be at most 64 characters',
      });
    }

    const existingUser = await User.findOne({
      $or: [{ email }, { staffId }],
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email
          ? 'Email already registered'
          : 'Staff ID already exists',
      });
    }

    const user = await User.create({ staffId, name, email, password });
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      data: {
        token,
        user: {
          id: user._id,
          staffId: user.staffId,
          name: user.name,
          email: user.email,
          role: user.role || 'staff',
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password, platform } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please enter email and password',
      });
    }

    const normalizedEmail = String(email).toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail }).select('+password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const isMatch = await user.comparePassword(password);

    if (!isMatch) {
      await recordAdminAccessLog({
        user,
        action: 'login_failed',
        platform,
        req,
        success: false,
      });
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const token = generateToken(user);

    await recordAdminAccessLog({
      user,
      action: 'login',
      platform,
      req,
      success: true,
    });

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        user: {
          id: user._id,
          staffId: user.staffId,
          name: user.name,
          email: user.email,
          role: user.role || 'staff',
        },
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.registerAdmin = async (req, res) => {
  try {
    const { name, email, password, adminSecret, autoStaffId } = req.body;
    let staffId = req.body.staffId != null ? String(req.body.staffId).trim() : '';
    const useAutoStaffId = autoStaffId === true || !staffId || staffId.toLowerCase() === 'auto';
    const ADMIN_SECRET = process.env.ADMIN_SECRET || 'admin123';

    if (!adminSecret || adminSecret !== ADMIN_SECRET) {
      return res.status(403).json({ success: false, message: 'Invalid admin secret' });
    }

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, email, and password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    if (useAutoStaffId) {
      staffId = await allocateNextId('ADM');
    }

    if (!staffId || staffId.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID is required, or enable automatic ID (autoStaffId / leave staffId empty)',
      });
    }

    if (staffId.length > 64) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID must be at most 64 characters',
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { staffId }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email ? 'Email already registered' : 'Staff ID already exists',
      });
    }

    const user = await User.create({ staffId, name, email, password, role: 'admin' });
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Admin registration successful',
      data: {
        token,
        user: {
          id: user._id,
          staffId: user.staffId,
          name: user.name,
          email: user.email,
          role: 'admin',
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.registerSupervisor = async (req, res) => {
  try {
    if (process.env.ALLOW_SUPERVISOR_SELF_REGISTER !== 'true') {
      return res.status(403).json({
        success: false,
        message: 'Supervisor accounts are managed by an administrator only. Ask admin to register staff, then use Admin → Staff pay → Promote to supervisor.',
      });
    }
    const { name, email, password, supervisorSecret, autoStaffId } = req.body;
    let staffId = req.body.staffId != null ? String(req.body.staffId).trim() : '';
    const useAutoStaffId = autoStaffId === true || !staffId || staffId.toLowerCase() === 'auto';
    const SUPERVISOR_SECRET = process.env.SUPERVISOR_SECRET || 'supervisor123';

    if (!supervisorSecret || supervisorSecret !== SUPERVISOR_SECRET) {
      return res.status(403).json({ success: false, message: 'Invalid supervisor secret' });
    }

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, email, and password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    if (useAutoStaffId) {
      staffId = await allocateNextId(AUTO_SUPERVISOR_PREFIX);
    }

    if (!staffId || staffId.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID is required, or enable automatic ID (autoStaffId / leave staffId empty)',
      });
    }

    if (staffId.length > 64) {
      return res.status(400).json({
        success: false,
        message: 'Staff ID must be at most 64 characters',
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { staffId }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email ? 'Email already registered' : 'Staff ID already exists',
      });
    }

    const user = await User.create({ staffId, name, email, password, role: 'supervisor' });
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Supervisor registration successful',
      data: {
        token,
        user: {
          id: user._id,
          staffId: user.staffId,
          name: user.name,
          email: user.email,
          role: 'supervisor',
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/** Minta kod reset — hantar ke email berdaftar (akaun dicipta admin). */
exports.forgotPassword = async (req, res) => {
  try {
    const email = String(req.body.email || '').toLowerCase().trim();
    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    if (!isEmailConfigured()) {
      return res.status(503).json({
        success: false,
        message: 'Email service is not configured. Ask admin to set SMTP settings in the API .env file.',
      });
    }

    const user = await User.findOne({ email }).select('+resetPasswordToken +resetPasswordExpires');
    const genericMessage =
      'If this email is registered, a reset code has been sent. Check your inbox (and spam folder).';

    if (!user) {
      return res.json({ success: true, message: genericMessage });
    }

    const resetCode = generateResetCode();
    user.resetPasswordToken = hashResetCode(resetCode);
    user.resetPasswordExpires = new Date(Date.now() + resetExpiryMinutes() * 60 * 1000);
    await user.save({ validateBeforeSave: false });

    try {
      await sendPasswordResetEmail({
        to: user.email,
        name: user.name,
        resetCode,
      });
    } catch (mailError) {
      user.resetPasswordToken = undefined;
      user.resetPasswordExpires = undefined;
      await user.save({ validateBeforeSave: false });
      return res.status(500).json({
        success: false,
        message: mailError.message || 'Failed to send reset email',
      });
    }

    if (process.env.NODE_ENV !== 'production' && process.env.LOG_RESET_CODE === 'true') {
      console.log(`[dev] Password reset code for ${user.email}: ${resetCode}`);
    }

    res.json({ success: true, message: genericMessage });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Set semula kata laluan dengan kod dari email. */
exports.resetPassword = async (req, res) => {
  try {
    const email = String(req.body.email || '').toLowerCase().trim();
    const code = String(req.body.code || req.body.resetCode || '').trim();
    const newPassword = req.body.newPassword;

    if (!email || !code || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email, reset code, and new password are required',
      });
    }

    if (String(newPassword).length < 6) {
      return res.status(400).json({
        success: false,
        message: 'New password must be at least 6 characters',
      });
    }

    const user = await User.findOne({ email }).select(
      '+password +resetPasswordToken +resetPasswordExpires'
    );

    if (
      !user ||
      !user.resetPasswordToken ||
      !user.resetPasswordExpires ||
      user.resetPasswordExpires.getTime() < Date.now()
    ) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset code',
      });
    }

    if (user.resetPasswordToken !== hashResetCode(code)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset code',
      });
    }

    user.password = String(newPassword);
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    await user.save();

    res.json({ success: true, message: 'Password reset successfully. You can now sign in.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/** Tukar kata laluan akaun sendiri (JWT). */
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, message: 'Current and new password are required' });
    }
    if (String(newPassword).length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
    }
    const user = await User.findById(req.user._id).select('+password');
    if (!user) {
      return res.status(401).json({ success: false, message: 'User not found' });
    }
    const isMatch = await user.comparePassword(String(currentPassword));
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Current password is incorrect' });
    }
    user.password = String(newPassword);
    await user.save();
    res.json({ success: true, message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
