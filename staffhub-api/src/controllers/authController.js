const User = require('../models/User');
const jwt = require('jsonwebtoken');
const { allocateNextId, AUTO_STAFF_PREFIX, AUTO_SUPERVISOR_PREFIX } = require('../utils/staffIdAllocator');

const JWT_SECRET = process.env.JWT_SECRET || 'staffhub-secret-key-change-in-production';

function generateToken(user) {
  return jwt.sign(
    { userId: user._id, staffId: user.staffId },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
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
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please enter email and password',
      });
    }

    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const isMatch = await user.comparePassword(password);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    const token = generateToken(user);

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
