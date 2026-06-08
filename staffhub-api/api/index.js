require('dotenv').config();
const serverless = require('serverless-http');
const connectDB = require('../src/config/db');
const app = require('../src/app');

const handler = serverless(app);

module.exports = async (req, res) => {
  await connectDB();
  return handler(req, res);
};
