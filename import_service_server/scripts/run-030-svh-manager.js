require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

async function main() {
  const sqlPath = path.join(__dirname, '..', 'sql', '030_svh_manager_role.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    multipleStatements: true,
  });
  await conn.query(sql);
  const [rows] = await conn.query("SHOW COLUMNS FROM organizations LIKE 'role'");
  console.log(rows[0]?.Type || rows);
  await conn.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
