const path = require('path');
const { normalizeDocType } = require('../constants/customsCatalog');

const KNOWN_EXT_RE =
  /\.(pdf|jpe?g|png|webp|gif|heic|bmp|mp4|mov|webm|mkv|avi|m4v|mp3|m4a|wav|aac|ogg|docx?|xlsx?)$/i;

function normalize(v) {
  return String(v ?? '').trim();
}

function hasKnownExtension(name) {
  return KNOWN_EXT_RE.test(normalize(name));
}

function extensionFromMime(mimeType) {
  const mt = normalize(mimeType).toLowerCase();
  if (mt === 'application/pdf') return '.pdf';
  if (mt === 'image/jpeg' || mt === 'image/jpg') return '.jpg';
  if (mt === 'image/png') return '.png';
  if (mt === 'image/webp') return '.webp';
  if (mt === 'video/mp4') return '.mp4';
  if (mt.startsWith('audio/')) return '.m4a';
  return '.bin';
}

function defaultBaseName(docType) {
  const dt = normalizeDocType(docType);
  if (!dt) return 'file';
  if (dt.endsWith('_sign')) return dt;
  if (/^transit_archive_photo_\d+$/.test(dt)) return dt;
  return dt.replace(/[^a-zA-Z0-9._-]/g, '_') || 'file';
}

function resolveExtension(docType, mimeType, clientFileName, storedName) {
  const fromClient = path.extname(normalize(clientFileName));
  if (fromClient && fromClient.length <= 12) return fromClient.toLowerCase();
  const fromStored = path.extname(normalize(storedName));
  if (fromStored && fromStored.length <= 12 && fromStored.toLowerCase() !== '.bin') {
    return fromStored.toLowerCase();
  }
  let ext = extensionFromMime(mimeType);
  const dt = normalizeDocType(docType);
  if (ext === '.bin' && dt.endsWith('_sign')) return '.pdf';
  if (ext === '.bin' && (dt.startsWith('payment_') || dt.includes('receipt'))) return '.pdf';
  return ext;
}

function isTechnicalStoredName(storedName, docType) {
  const base = path.basename(normalize(storedName));
  const dt = normalizeDocType(docType);
  if (!base || !dt) return false;
  const escaped = dt.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`^[^/\\\\]+__${escaped}\\.`, 'i').test(base);
}

/**
 * Человекочитаемое имя с расширением для API и исходящих вызовов в 1С.
 */
function ensureDisplayFileName({ docType, mimeType, storedName, clientFileName }) {
  const client = normalize(clientFileName);
  if (client && hasKnownExtension(client)) {
    return client.slice(0, 255);
  }

  const storedBase = path.basename(normalize(storedName));
  if (storedBase && hasKnownExtension(storedBase) && !isTechnicalStoredName(storedBase, docType)) {
    return storedBase.slice(0, 255);
  }

  const ext = resolveExtension(docType, mimeType, client, storedName);
  const safeExt = ext.startsWith('.') ? ext : `.${ext}`;
  let base = client ? path.basename(client, path.extname(client)) : defaultBaseName(docType);
  base = base.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 200) || defaultBaseName(docType);
  return `${base}${safeExt}`.slice(0, 255);
}

module.exports = {
  ensureDisplayFileName,
  hasKnownExtension,
};
