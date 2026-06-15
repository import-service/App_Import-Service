require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
const mysql = require('mysql2/promise');

async function main() {
  const sqlPath = require('path').join(__dirname, '..', 'sql', '011_add_one_c_request_update_settings.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const conn = await mysql.createConnection({
    host: String(process.env.MYSQL_HOST || '127.0.0.1').trim(),
    user: String(process.env.MYSQL_USER || '').trim(),
    password: String(process.env.MYSQL_PASSWORD || '').trim(),
    database: String(process.env.MYSQL_DATABASE || '').trim(),
    multipleStatements: true,
  });
  await conn.query(sql);
  const [rows] = await conn.query(
    `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'app_settings'
       AND COLUMN_NAME IN ('one_c_request_update_url', 'one_c_request_update_bearer_token')`,
  );
  console.log('OK columns:', rows.map((r) => r.COLUMN_NAME).join(', '));
  await conn.end();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
