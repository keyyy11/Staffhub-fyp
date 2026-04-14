const User = require('../models/User');

exports.getProfile = async (req, res) => {
  try {
    const { staffId } = req.params;

    const user = await User.findOne({ staffId }).select('-password');
    if (!user) {
      // 200 supaya UI boleh gabung dengan data login tempatan (demo / DB kosong)
      return res.json({
        success: true,
        data: {
          staffId,
          name: '',
          email: '',
          phone: '',
          department: '',
          position: '',
          profileImage: '',
        },
      });
    }

    res.json({
      success: true,
      data: {
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        department: user.department || '',
        position: user.position || '',
        profileImage: user.profileImage || '',
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const { staffId } = req.params;
    const { name, phone, department, position, profileImage } = req.body;

    const user = await User.findOne({ staffId });
    if (!user) {
      return res.status(200).json({
        success: false,
        message:
          'No user record for this Staff ID in the database. Register first or use a normal login.',
      });
    }

    if (name !== undefined) user.name = name;
    if (phone !== undefined) user.phone = phone;
    if (department !== undefined) user.department = department;
    if (position !== undefined) user.position = position;
    if (profileImage !== undefined) user.profileImage = profileImage;

    await user.save();

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        staffId: user.staffId,
        name: user.name,
        email: user.email,
        phone: user.phone || '',
        department: user.department || '',
        position: user.position || '',
        profileImage: user.profileImage || '',
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
