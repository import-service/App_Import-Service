const { submitCustomsRequestTo1CFromDb } = require('./oneCRequestCreate');

function buildOneCCreateErrorJson(result) {
  if (!result || result.ok || result.skipped) return null;
  return JSON.stringify({
    code: result.error || 'ONE_C_CREATE_FAILED',
    httpStatus: result.oneC?.httpStatus ?? null,
    responseBody: result.oneC?.responseBody ?? null,
    oneCMessage: result.oneC?.oneCMessage ?? null,
    reason: result.reason || null,
  });
}

async function markOneCCreatePending(pool, requestId, result) {
  await pool.query(
    `UPDATE customs_requests
     SET one_c_create_pending = 1,
         one_c_create_last_error_json = ?,
         one_c_create_last_attempt_at = CURRENT_TIMESTAMP(3),
         one_c_create_first_failed_at = COALESCE(one_c_create_first_failed_at, CURRENT_TIMESTAMP(3))
     WHERE id = ? AND deleted_at IS NULL`,
    [buildOneCCreateErrorJson(result), requestId],
  );
}

async function markOneCCreateSynced(pool, requestId) {
  await pool.query(
    `UPDATE customs_requests
     SET one_c_create_pending = 0,
         one_c_create_last_error_json = NULL,
         one_c_create_last_attempt_at = CURRENT_TIMESTAMP(3),
         one_c_create_first_failed_at = NULL
     WHERE id = ? AND deleted_at IS NULL`,
    [requestId],
  );
}

/**
 * Исходящий create в 1С + флаг в БД.
 */
async function pushCustomsRequestCreateTo1C(fastify, requestId) {
  const result = await submitCustomsRequestTo1CFromDb(fastify, requestId);
  if (result.ok) {
    await markOneCCreateSynced(fastify.pool, requestId);
  } else if (!result.skipped) {
    await markOneCCreatePending(fastify.pool, requestId, result);
  }
  return result;
}

module.exports = {
  pushCustomsRequestCreateTo1C,
  markOneCCreatePending,
  markOneCCreateSynced,
};
