const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const routes = require('./routes');
const cors = require('cors');
const db = require('./configs/db'); // Import the db connection

const app = express();

app.use(cors());
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
