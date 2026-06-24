const { normalizeDocType } = require('../constants/customsCatalog');
const { ensureDisplayFileName } = require('./displayFileName');

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
  const dt = normalizeDocType(docType);
  const storedName = file.storedName ?? file.stored_name ?? '';
  const clientName = file.fileName ?? file.original_name ?? file.originalName ?? '';
  return {
    docType: dt,
    fileName: ensureDisplayFileName({
      docType: dt,
      mimeType: file.mimeType ?? file.mime_type ?? null,
      storedName: storedName || clientName,
      clientFileName: clientName,
    }),
    mimeType: file.mimeType ?? file.mime_type ?? null,
    fileUrl: file.fileUrl ?? file.file_url ?? '',
  };
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
  INTEGRATION_FILE_ITEM_SCHEMA,
};
