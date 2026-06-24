const { submitCustomsRequestUpdateTo1CFromDb } = require('./oneCRequestUpdate');

function buildOneCUpdateErrorJson(result) {
  if (!result || result.ok || result.skipped) return null;
  return JSON.stringify({
    code: result.error || 'ONE_C_UPDATE_FAILED',
    httpStatus: result.oneC?.httpStatus ?? null,
    responseBody: result.oneC?.responseBody ?? null,
    oneCMessage: result.oneC?.oneCMessage ?? null,
    reason: result.reason || null,
  });
}

async function markOneCUpdatePending(pool, requestId, result) {
  await pool.query(
    `UPDATE customs_requests
     SET one_c_update_pending = 1,
         one_c_update_last_error_json = ?,
         one_c_update_last_attempt_at = CURRENT_TIMESTAMP(3),
         one_c_update_first_failed_at = COALESCE(one_c_update_first_failed_at, CURRENT_TIMESTAMP(3))
     WHERE id = ? AND deleted_at IS NULL`,
    [buildOneCUpdateErrorJson(result), requestId],
  );
}

async function markOneCUpdateSynced(pool, requestId) {
  await pool.query(
    `UPDATE customs_requests
     SET one_c_update_pending = 0,
         one_c_update_last_error_json = NULL,
         one_c_update_last_attempt_at = CURRENT_TIMESTAMP(3),
         one_c_update_first_failed_at = NULL
     WHERE id = ? AND deleted_at IS NULL`,
    [requestId],
  );
}

/**
 * Исходящий update в 1С + синхронизация флага в БД.
 * skipped (нет URL / нет external1cId) — флаг не трогаем.
 */
async function pushCustomsRequestUpdateTo1C(fastify, requestId, options = {}) {
  const result = await submitCustomsRequestUpdateTo1CFromDb(fastify, requestId, options);
  if (result.ok) {
    await markOneCUpdateSynced(fastify.pool, requestId);
  } else if (!result.skipped) {
    await markOneCUpdatePending(fastify.pool, requestId, result);
  }
  return result;
}

module.exports = {
  pushCustomsRequestUpdateTo1C,
  markOneCUpdatePending,
  markOneCUpdateSynced,
};
