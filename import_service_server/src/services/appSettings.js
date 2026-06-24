async function getAppSettings(pool) {
  const [rows] = await pool.query(
    `SELECT one_c_request_create_url, one_c_request_create_bearer_token,
            one_c_request_update_url, one_c_request_update_bearer_token,
            retention_months, one_c_outbound_alert_last_at, updated_at
     FROM app_settings WHERE id = 1 LIMIT 1`,
  );
  const row = rows[0] || {};
  return {
    oneCRequestCreateUrl: String(row.one_c_request_create_url || '').trim(),
    oneCRequestCreateBearerToken: String(row.one_c_request_create_bearer_token || '').trim(),
    oneCRequestUpdateUrl: String(row.one_c_request_update_url || '').trim(),
    oneCRequestUpdateBearerToken: String(row.one_c_request_update_bearer_token || '').trim(),
    retentionMonths: Math.max(1, Math.min(120, Number(row.retention_months) || 6)),
    oneCOutboundAlertLastAt: row.one_c_outbound_alert_last_at || null,
    updatedAt: row.updated_at || null,
  };
}

async function updateRetentionMonths(pool, retentionMonths) {
  const months = Math.max(1, Math.min(120, Number(retentionMonths) || 6));
  await pool.query(`UPDATE app_settings SET retention_months = ? WHERE id = 1`, [months]);
  return getAppSettings(pool);
}

async function updateOneCRequestCreateSettings(pool, { url, updateUrl, bearerToken }) {
  const current = await getAppSettings(pool);
  const incomingToken =
    bearerToken === undefined ? undefined : String(bearerToken || '').trim();
  let tokenToSave;
  if (incomingToken === undefined || incomingToken === '') {
    tokenToSave = current.oneCRequestCreateBearerToken || null;
  } else {
    tokenToSave = incomingToken;
  }

  const normalizedUpdateUrl =
    updateUrl === undefined ? undefined : String(updateUrl || '').trim() || null;
  if (normalizedUpdateUrl === undefined) {
    await pool.query(
      `UPDATE app_settings
       SET one_c_request_create_url = ?, one_c_request_create_bearer_token = ?
       WHERE id = 1`,
      [url || null, tokenToSave],
    );
  } else {
    await pool.query(
      `UPDATE app_settings
       SET one_c_request_create_url = ?, one_c_request_create_bearer_token = ?,
           one_c_request_update_url = ?
       WHERE id = 1`,
      [url || null, tokenToSave, normalizedUpdateUrl],
    );
  }
  return getAppSettings(pool);
}

module.exports = {
  getAppSettings,
  updateOneCRequestCreateSettings,
  updateRetentionMonths,
};
