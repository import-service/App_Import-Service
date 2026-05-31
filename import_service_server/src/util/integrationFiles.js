const { normalizeDocType } = require('../constants/customsCatalog');

function isSignedDocType(docType) {
  return String(docType || '').trim().endsWith('_sign');
}

/** Файлы, которые клиент загружает из МП и сервер передаёт в 1С через update. */
function isClientUploadedDocType(docType) {
  const t = normalizeDocType(docType);
  if (!t) return false;
  if (isSignedDocType(t)) return true;
  if (t === 'payment_recycling_fee_receipt' || t === 'payment_customs_duty_receipt') return true;
  if (t === 'payment_recycling_fee' || t === 'payment_customs_duty') return true;
  if (t === 'add_doc1' || t === 'add_doc2') return true;
  return false;
}

/** Элемент файла в контракте 1С ↔ сервер. */
function toIntegrationFileRef(file) {
  if (!file) return null;
  const docType = file.docType ?? file.doc_type;
  return {
    docType: normalizeDocType(docType),
    fileName: file.fileName ?? file.original_name ?? file.originalName ?? '',
    mimeType: file.mimeType ?? file.mime_type ?? null,
    fileUrl: file.fileUrl ?? file.file_url ?? '',
  };
}

/**
 * Файлы из тела state (1С → сервер).
 * Основное поле: files[]. Совместимость: unsigned[], signingFiles[].
 */
function resolveFilesFromStateBody(body) {
  if (Array.isArray(body?.files) && body.files.length > 0) {
    return body.files;
  }
  if (Array.isArray(body?.unsigned) && body.unsigned.length > 0) {
    return body.unsigned;
  }
  if (Array.isArray(body?.signingFiles) && body.signingFiles.length > 0) {
    return body.signingFiles;
  }
  return [];
}

const INTEGRATION_FILE_ITEM_SCHEMA = {
  type: 'object',
  required: ['docType', 'fileName', 'fileUrl'],
  properties: {
    docType: { type: 'string', minLength: 1, maxLength: 64 },
    fileName: { type: 'string', minLength: 1, maxLength: 255 },
    mimeType: { type: 'string', maxLength: 128 },
    fileUrl: { type: 'string', minLength: 1, maxLength: 1024 },
  },
};

module.exports = {
  isSignedDocType,
  isClientUploadedDocType,
  toIntegrationFileRef,
  resolveFilesFromStateBody,
  INTEGRATION_FILE_ITEM_SCHEMA,
};
