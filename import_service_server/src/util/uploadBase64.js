const { maxBytesForUpload, formatLimitMb, LIMIT_PHOTO_DOC_BYTES } = require('../constants/uploadLimits');
const { resolveFileKind } = require('./fileKindDetect');

/** Поля base64, которые может прислать 1С (HTTPЗапрос + JSON). */
const BASE64_FIELD_KEYS = [
  'fileBase64',
  'file',
  'fileContent',
  'base64',
  'content',
  'data',
  'FileBase64',
  'File',
  'ДанныеФайла',
  'ДвоичныеДанные',
];

function normalize(v) {
  return String(v ?? '').trim();
}

function extractBase64FromBody(body) {
  if (!body || typeof body !== 'object') return '';
  for (const key of BASE64_FIELD_KEYS) {
    const val = body[key];
    if (val != null && String(val).trim()) {
      return String(val).trim();
    }
  }
  return '';
}

function decodeBase64Payload(raw) {
  let s = normalize(raw);
  if (!s) {
    throw new Error('VALIDATION_ERROR: пустые данные файла (base64)');
  }

  const dataUrl = /^data:([^;]+);base64,(.+)$/is.exec(s);
  if (dataUrl) {
    const buffer = Buffer.from(dataUrl[2], 'base64');
    return {
      buffer,
      mimeType: normalize(dataUrl[1]) || null,
    };
  }

  if (s.includes(',')) {
    const commaIdx = s.lastIndexOf(',');
    const maybePayload = s.slice(commaIdx + 1).trim();
    if (/^[A-Za-z0-9+/=\s]+$/.test(maybePayload)) {
      s = maybePayload.replace(/\s/g, '');
    }
  } else {
    s = s.replace(/\s/g, '');
  }

  const buffer = Buffer.from(s, 'base64');
  if (!buffer.length) {
    throw new Error('VALIDATION_ERROR: не удалось декодировать base64');
  }
  return { buffer, mimeType: null };
}

/**
 * Общий парсер JSON + base64 для 1С (заявка и чат).
 * @param {object} body
 * @param {{ requireDocType?: boolean, requireUploadBatch?: boolean }} options
 */
function parseIntegrationFileBase64Body(body, options = {}) {
  const requireDocType = Boolean(options.requireDocType);
  const requireUploadBatch = Boolean(options.requireUploadBatch);

  const external1cId = normalize(body?.external1cId);
  const docType = normalize(body?.docType);
  const uploadIndex = Number(body?.uploadIndex);
  const uploadTotal = Number(body?.uploadTotal);
  const fileName = normalize(body?.fileName || body?.file_name || body?.name);
  const mimeType = normalize(body?.mimeType || body?.mime_type || body?.contentType);

  if (!external1cId) {
    throw new Error('VALIDATION_ERROR: external1cId обязателен');
  }
  if (requireDocType && !docType) {
    throw new Error('VALIDATION_ERROR: docType обязателен');
  }

  const resolvedMime = mimeType || null;
  const { buffer, mimeType: mimeFromDataUrl } = decodeBase64Payload(extractBase64FromBody(body));
  const declaredMime = resolvedMime || mimeFromDataUrl || '';
  const kind = resolveFileKind({
    buffer,
    clientFileName: fileName,
    mimeType: declaredMime || 'application/octet-stream',
  });
  const finalMime = kind.mimeType;
  const maxBytes = requireDocType
    ? maxBytesForUpload(docType, finalMime)
    : LIMIT_PHOTO_DOC_BYTES;
  if (buffer.length > maxBytes) {
    throw new Error(`VALIDATION_ERROR: файл больше ${formatLimitMb(maxBytes)}`);
  }

  const result = {
    external1cId,
    fileName: fileName || undefined,
    mimeType: finalMime,
    sourceMimeType: declaredMime || null,
    buffer,
  };

  if (requireDocType) {
    result.docType = docType;
    result.uploadIndex = uploadIndex;
    result.uploadTotal = uploadTotal;
  }

  if (requireUploadBatch && requireDocType) {
    if (!Number.isFinite(uploadIndex) || uploadIndex < 1) {
      throw new Error('VALIDATION_ERROR: uploadIndex обязателен');
    }
    if (!Number.isFinite(uploadTotal) || uploadTotal < 1) {
      throw new Error('VALIDATION_ERROR: uploadTotal обязателен');
    }
  }

  return result;
}

function parseOneCUploadJsonBody(body) {
  return parseIntegrationFileBase64Body(body, {
    requireDocType: true,
    requireUploadBatch: false,
  });
}

/** JSON + base64 для вложения чата (1С). Без docType / uploadIndex. */
function parseChatAttachmentJsonBody(body) {
  return parseIntegrationFileBase64Body(body, {
    requireDocType: false,
    requireUploadBatch: false,
  });
}

module.exports = {
  parseOneCUploadJsonBody,
  parseChatAttachmentJsonBody,
  parseIntegrationFileBase64Body,
  extractBase64FromBody,
  decodeBase64Payload,
};
