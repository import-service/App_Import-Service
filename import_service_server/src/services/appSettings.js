async function getAppSettings(pool) {
  const [rows] = await pool.query(
    `SELECT one_c_request_create_url, one_c_request_create_bearer_token, updated_at
     FROM app_settings WHERE id = 1 LIMIT 1`,
  );
  const row = rows[0] || {};
  return {
    oneCRequestCreateUrl: String(row.one_c_request_create_url || '').trim(),
    oneCRequestCreateBearerToken: String(row.one_c_request_create_bearer_token || '').trim(),
    updatedAt: row.updated_at || null,
  };
}

async function updateOneCRequestCreateSettings(pool, { url, bearerToken }) {
  await pool.query(
    `UPDATE app_settings
     SET one_c_request_create_url = ?, one_c_request_create_bearer_token = ?
     WHERE id = 1`,
    [url || null, bearerToken || null],
  );
  return getAppSettings(pool);
}

module.exports = {
  getAppSettings,
  updateOneCRequestCreateSettings,
};
