const { toCustomsRequestDto } = require('../util/customsRequestDto');

async function buildRequestDetailPayloadById(fastify, requestId) {
  const [rows] = await fastify.pool.query(
    `SELECT * FROM customs_requests WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    [requestId],
  );
  if (!rows.length) return null;
  const [fileRows] = await fastify.pool.query(
    `SELECT id, doc_type, original_name, stored_name, mime_type, file_size_bytes, file_url, created_at, updated_at
     FROM customs_request_files
     WHERE request_id = ? AND deleted_at IS NULL
     ORDER BY id ASC`,
    [requestId],
  );

  const dto = toCustomsRequestDto(
    fastify,
    { headers: {} },
    rows[0],
    fileRows,
    { includeFiles: true, mergeVehicleFiles: true },
  );
  return {
    requestId: Number(requestId),
    external1cId: dto.external1cId || null,
    status: dto.status || null,
    statusSubType: dto.statusSubType || null,
    statusSubTypeDateTime: dto.statusSubTypeDateTime || null,
    dealType: dto.dealType || null,
    managerExternal1cId: dto.managerExternal1cId || null,
    managerFullName: dto.managerFullName || null,
    ownerFullName: dto.ownerFullName || null,
    carMake: dto.carMake || null,
    carModel: dto.carModel || null,
    vin: dto.vin || null,
    engineSpec: dto.engineSpec || null,
    engineVolume: dto.engineVolume || null,
    statusSinceDateLabel: dto.statusSinceDateLabel || null,
    financeItems: Array.isArray(dto.financeItems) ? dto.financeItems : [],
    vehiclePhotoUrls: Array.isArray(dto.vehiclePhotoUrls) ? dto.vehiclePhotoUrls : [],
    deliveredDocuments: Array.isArray(dto.deliveredDocuments) ? dto.deliveredDocuments : [],
    signingFiles: Array.isArray(dto.files) ? dto.files : [],
    source: 'import_service_server',
  };
}

module.exports = { buildRequestDetailPayloadById };

