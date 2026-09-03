require('dotenv').config();
const { pool } = require('../src/db');
const config = require('../src/config');
const { runStoreVersionScan } = require('../src/services/storeVersionScanner');

async function main() {
  const fastify = {
    pool,
    config,
    log: {
      info: (...args) => console.log(...args),
      warn: (...args) => console.warn(...args),
      error: (...args) => console.error(...args),
    },
  };
  const result = await runStoreVersionScan(fastify);
  console.log(JSON.stringify(result, null, 2));
  await pool.end();
}

main().catch((e) => {
  console.error(e.stack || e.message || String(e));
  process.exit(1);
});
