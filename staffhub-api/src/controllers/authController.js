const User = require('../models/User');
const jwt = require('jsonwebtoken');

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
    const { staffId, name, email, password } = req.body;

    if (!staffId || !name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please fill all fields: staffId, name, email, password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
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
    const { staffId, name, email, password, adminSecret } = req.body;
    const ADMIN_SECRET = process.env.ADMIN_SECRET || 'admin123';

    if (adminSecret !== ADMIN_SECRET) {
      return res.status(403).json({ success: false, message: 'Invalid admin secret' });
    }

    if (!staffId || !name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please fill all fields: staffId, name, email, password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
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
