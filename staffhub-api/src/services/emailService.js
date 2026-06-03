const nodemailer = require('nodemailer');

function isEmailConfigured() {
  return Boolean(
    process.env.SMTP_HOST &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASS
  );
}

function createTransporter() {
  if (!isEmailConfigured()) {
    return null;
  }

  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

async function sendPasswordResetEmail({ to, name, resetCode }) {
  const transporter = createTransporter();
  if (!transporter) {
    throw new Error(
      'Email is not configured. Set SMTP_HOST, SMTP_USER, and SMTP_PASS in .env'
    );
  }

  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  const appName = process.env.APP_NAME || 'Staff Hub';
  const expiryMinutes = process.env.RESET_CODE_EXPIRY_MINUTES || '15';

  await transporter.sendMail({
    from: `"${appName}" <${from}>`,
    to,
    subject: `${appName} — Reset your password`,
    text: [
      `Hi ${name},`,
      '',
      `You requested a password reset for your ${appName} account.`,
      '',
      `Your reset code: ${resetCode}`,
      '',
      `This code expires in ${expiryMinutes} minutes.`,
      'Open the app → Forgot password → enter this code with your new password.',
      '',
      'If you did not request this, you can ignore this email.',
    ].join('\n'),
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; color: #1a1a1a;">
        <h2 style="color: #1565c0;">${appName}</h2>
        <p>Hi ${name},</p>
        <p>You requested a password reset for your ${appName} account.</p>
        <p style="font-size: 28px; letter-spacing: 6px; font-weight: bold; color: #1565c0; margin: 24px 0;">
          ${resetCode}
        </p>
        <p>This code expires in <strong>${expiryMinutes} minutes</strong>.</p>
        <p>Open the app, go to <strong>Forgot password</strong>, and enter this code with your new password.</p>
        <p style="color: #666; font-size: 13px;">If you did not request this, you can ignore this email.</p>
      </div>
    `,
  });
}

module.exports = {
  isEmailConfigured,
  sendPasswordResetEmail,
};
