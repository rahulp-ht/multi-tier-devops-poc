const fs = require('fs');
const mysql = require('mysql2');

const db = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD_FILE
    ? fs.readFileSync(process.env.DB_PASSWORD_FILE, 'utf8').trimEnd()
    : process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'react_node_app',

  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

module.exports = db;
