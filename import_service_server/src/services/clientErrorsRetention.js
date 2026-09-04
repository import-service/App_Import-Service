const RETENTION_DAYS = 14;

async function purgeOldClientErrors(pool, days = RETENTION_DAYS) {
  const [result] = await pool.query(
    `DELETE FROM client_errors
     WHERE created_at < (NOW(3) - INTERVAL ? DAY)`,
    [days],
  );
  return { deleted: result.affectedRows || 0, retentionDays: days };
}

module.exports = {
  CLIENT_ERRORS_RETENTION_DAYS: RETENTION_DAYS,
  purgeOldClientErrors,
};
