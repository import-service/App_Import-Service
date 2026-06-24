const { docTypeCategory } = require('./customsCatalog');

const LIMIT_PHOTO_DOC_BYTES = 25 * 1024 * 1024;
const LIMIT_MEDIA_BYTES = 100 * 1024 * 1024;
/** Тело HTTP для JSON+base64 (≈×1.37 от 100 МБ). */
const HTTP_BODY_LIMIT_BYTES = 150 * 1024 * 1024;
const MULTIPART_MAX_BYTES = LIMIT_MEDIA_BYTES;

function normalizeMime(mimeType) {
  return String(mimeType ?? '').trim().toLowerCase();
}

function isVideoDocType(docType) {
  const c = String(docType ?? '').trim();
  if (c === 'transit_archive_video') return true;
  return /_video$/i.test(c);
}

function isAudioDocType(docType) {
  const c = String(docType ?? '').trim();
  return /_audio$/i.test(c) || c === 'transit_archive_audio';
}

function isMediaMime(mimeType) {
  const mt = normalizeMime(mimeType);
  return mt.startsWith('video/') || mt.startsWith('audio/');
}

function maxBytesForUpload(docType, mimeType) {
  if (isVideoDocType(docType) || isAudioDocType(docType) || isMediaMime(mimeType)) {
    return LIMIT_MEDIA_BYTES;
  }
  return LIMIT_PHOTO_DOC_BYTES;
}

function formatLimitMb(bytes) {
  return `${Math.round(bytes / (1024 * 1024))} МБ`;
}

function assertFileSizeAllowed(sizeBytes, docType, mimeType) {
  const max = maxBytesForUpload(docType, mimeType);
  if (sizeBytes > max) {
    throw new Error(
      `VALIDATION_ERROR: файл больше ${formatLimitMb(max)} (docType=${String(docType || '').trim() || '?'})`,
    );
  }
}

function isImageMime(mimeType) {
  const mt = normalizeMime(mimeType);
  return mt.startsWith('image/');
}

function shouldGeneratePreview(docType, mimeType) {
  if (isImageMime(mimeType)) return true;
  const cat = docTypeCategory(docType);
  if (cat === 'creation' || cat === 'transit_archive') {
    const c = String(docType ?? '').toLowerCase();
    if (c.includes('photo') || c.includes('image')) return true;
  }
  return false;
}

module.exports = {
  LIMIT_PHOTO_DOC_BYTES,
  LIMIT_MEDIA_BYTES,
  HTTP_BODY_LIMIT_BYTES,
  MULTIPART_MAX_BYTES,
  maxBytesForUpload,
  assertFileSizeAllowed,
  formatLimitMb,
  isImageMime,
  shouldGeneratePreview,
  isVideoDocType,
  isAudioDocType,
};
