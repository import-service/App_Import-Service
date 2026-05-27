#!/usr/bin/env node
/**
 * Применить один .sql файл: node scripts/apply-sql-file.js sql/009_....sql
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

async function main() {
  const rel = process.argv[2];
  if (!rel) {
    console.error('Usage: node scripts/apply-sql-file.js <path-to.sql>');
    process.exit(1);
  }
  const file = path.isAbsolute(rel) ? rel : path.join(process.cwd(), rel);
  const sql = fs.readFileSync(file, 'utf8');
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
  console.log('ok:', rel);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
