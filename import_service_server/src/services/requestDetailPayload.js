const { toCustomsRequestDto, toAbsoluteUrl } = require('../util/customsRequestDto');
const { toIntegrationFileRef, isClientUploadedDocType } = require('../util/integrationFiles');
const { CUSTOMS_REQUEST_FILE_SELECT } = require('../util/requestFileStorage');

function apiBaseFromFastify(fastify, requestLike) {
  const proto = String(requestLike?.headers?.['x-forwarded-proto'] || '')
    .split(',')[0]
    .trim() || 'https';
  const host = String(requestLike?.headers?.['x-forwarded-host'] || requestLike?.headers?.host || '')
    .split(',')[0]
    .trim() || 'localhost';
  return `${proto}://${host}/api`;
}

function mapFilesForOneC(fastify, requestLike, files) {
  const base = apiBaseFromFastify(fastify, requestLike);
  return (files || [])
    .map((f) => toIntegrationFileRef(f))
    .filter((f) => f?.docType && f.fileUrl)
    .map((f) => ({
      ...f,
      fileUrl: toAbsoluteUrl(f.fileUrl, base) || f.fileUrl,
    }));
}

async function fetchRequestRowAndFiles(fastify, requestId) {
  const [rows] = await fastify.pool.query(
    `SELECT * FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  if (!rows.length) return null;
  const [fileRows] = await fastify.pool.query(
    `SELECT ${CUSTOMS_REQUEST_FILE_SELECT}
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [requestId],
  );
  return { row: rows[0], fileRows };
}

/**
 * Исходящий update в 1С после загрузок из МП: только идентификаторы и новые файлы (URL + docType).
 * Статусы и прочие поля 1С получает только через входящий state (1С → сервер).
 */
async function buildOneCFilesUpdatePayload(fastify, requestId, files, requestLike) {
  const data = await fetchRequestRowAndFiles(fastify, requestId);
  if (!data) return null;

  const dto = toCustomsRequestDto(
    fastify,
    requestLike || { headers: {} },
    data.row,
    data.fileRows,
    { includeFiles: true, mergeVehicleFiles: false },
  );

  return {
    requestId: Number(requestId),
    external1cId: dto.external1cId || null,
    files: mapFilesForOneC(fastify, requestLike, files),
  };
}

/** Повтор update: все файлы, загруженные клиентом из МП (подписи, чеки оплаты, доп. документы). */
async function buildOneCFilesUpdatePayloadForResend(fastify, requestId) {
  const data = await fetchRequestRowAndFiles(fastify, requestId);
  if (!data) return null;

  const dto = toCustomsRequestDto(
    fastify,
    { headers: {} },
    data.row,
    data.fileRows,
    { includeFiles: true, mergeVehicleFiles: false },
  );

  const clientFiles = (dto.files || []).filter((f) => isClientUploadedDocType(f.docType));

  return {
    requestId: Number(requestId),
    external1cId: dto.external1cId || null,
    files: mapFilesForOneC(fastify, { headers: {} }, clientFiles),
  };
}

module.exports = {
  buildOneCFilesUpdatePayload,
  buildOneCFilesUpdatePayloadForResend,
};
