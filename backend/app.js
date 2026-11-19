const express = require('express');
const bodyParser = require('body-parser');
const routes = require('./routes');
const cors = require('cors');
const db = require('./configs/db'); // Import the db connection

const app = express();

app.disable('x-powered-by');

const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS ||
  'http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://127.0.0.1:8080')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(cors({ origin: allowedOrigins }));
app.use(bodyParser.json());

db.getConnection((err, connection) => {
  if (err) {
    console.error('Database connection failed:', {
      code: err.code,
      message: err.message
    });
    return;
  }

  console.log('Database connection successful');
  connection.release();
});
// Health check for AWS Application Load Balancer
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'backend'
  });
});
// Add your routes here
app.use('/api', routes);

module.exports = app;
