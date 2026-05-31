const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function main() {
  const rel = process.argv[2];
  if (!rel) {
    throw new Error('Usage: node src/runSqlMigration.js <sql-file>');
  }

  const filePath = path.isAbsolute(rel) ? rel : path.join(process.cwd(), rel);
  const sql = fs.readFileSync(filePath, 'utf8');

  const conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    multipleStatements: true,
  });
  await conn.query(sql);
  await conn.end();
  process.stdout.write(`MIGRATION_OK ${rel}\n`);
}

main().catch((e) => {
  process.stderr.write(`${e.stack || e.message || String(e)}\n`);
  process.exit(1);
});
