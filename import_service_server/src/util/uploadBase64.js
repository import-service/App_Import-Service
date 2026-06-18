const MAX_FILE_BYTES = 25 * 1024 * 1024;

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

function parseOneCUploadJsonBody(body) {
  const external1cId = normalize(body?.external1cId);
  const docType = normalize(body?.docType);
  const uploadIndex = Number(body?.uploadIndex);
  const uploadTotal = Number(body?.uploadTotal);
  const fileName = normalize(body?.fileName || body?.file_name || body?.name);
  const mimeType = normalize(body?.mimeType || body?.mime_type || body?.contentType);

  if (!external1cId) {
    throw new Error('VALIDATION_ERROR: external1cId обязателен');
  }
  if (!docType) {
    throw new Error('VALIDATION_ERROR: docType обязателен');
  }

  const { buffer, mimeType: mimeFromDataUrl } = decodeBase64Payload(extractBase64FromBody(body));
  if (buffer.length > MAX_FILE_BYTES) {
    throw new Error('VALIDATION_ERROR: файл больше 25 МБ');
  }

  return {
    external1cId,
    docType,
    uploadIndex,
    uploadTotal,
    fileName,
    mimeType: mimeType || mimeFromDataUrl || 'application/octet-stream',
    buffer,
  };
}

module.exports = {
  parseOneCUploadJsonBody,
  extractBase64FromBody,
  decodeBase64Payload,
  MAX_FILE_BYTES,
};
