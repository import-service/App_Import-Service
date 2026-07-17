const path = require('path');
const { kindFromMagic } = require('./fileKindDetect');

const MAX_EXTRACTED_BYTES = 40 * 1024 * 1024; // 40 MB на один файл
const MAX_FILES_PER_ARCHIVE = 50;

function bufferToArrayBuffer(buffer) {
  return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
}

function entryBaseName(name) {
  const n = String(name || '').replace(/\\/g, '/');
  const parts = n.split('/').filter(Boolean);
  return parts[parts.length - 1] || n;
}

function isImageName(name) {
  const ext = path.extname(entryBaseName(name)).toLowerCase();
  return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext);
}

function isPdfName(name) {
  return path.extname(entryBaseName(name)).toLowerCase() === '.pdf';
}

function preferImages(docType) {
  const dt = String(docType || '').toLowerCase();
  if (/transit_archive_photo/.test(dt) || dt.includes('_photo')) return true;
  return [
    'passport_front',
    'passport_registration',
    'inn',
    'snils',
    'car_nameplate_photo',
    'car_mileage_photo',
    'car_front_photo',
    'car_back_photo',
  ].includes(dt);
}

/** Отсортировать по имени (натурально), затем картинки/pdf по приоритету docType. */
function orderCandidates(list, docType) {
  const sorted = [...list].sort((a, b) =>
    entryBaseName(a.name).localeCompare(entryBaseName(b.name), 'ru', { numeric: true }),
  );
  const images = sorted.filter((h) => isImageName(h.name));
  const pdfs = sorted.filter((h) => isPdfName(h.name));
  return preferImages(docType) ? [...images, ...pdfs] : [...pdfs, ...images];
}

function toResult(buf, fileName) {
  const magic = kindFromMagic(buf);
  if (!magic) return null;
  if (!magic.mimeType.startsWith('image/') && magic.mimeType !== 'application/pdf') {
    return null;
  }
  return {
    buffer: buf,
    fileName: entryBaseName(fileName),
    mimeType: magic.mimeType,
  };
}

async function extractAllFromRar(buffer, docType, max) {
  // eslint-disable-next-line global-require, import/no-extraneous-dependencies
  const unrar = require('node-unrar-js');
  const extractor = await unrar.createExtractorFromData({
    data: bufferToArrayBuffer(buffer),
  });
  const headers = [...extractor.getFileList().fileHeaders]
    .filter((h) => h && !h.flags?.directory)
    .map((h) => ({ name: h.name, size: h.unpSize }));
  const ordered = orderCandidates(headers, docType);
  if (!ordered.length) return [];

  const extracted = extractor.extract({ files: ordered.map((h) => h.name) });
  const byName = new Map();
  for (const f of extracted.files) {
    if (f?.fileHeader?.name && f.extraction) {
      byName.set(f.fileHeader.name, f.extraction);
    }
  }

  const out = [];
  for (const h of ordered) {
    if (out.length >= max) break;
    const data = byName.get(h.name);
    if (!data) continue;
    const buf = Buffer.from(data);
    if (buf.length > MAX_EXTRACTED_BYTES) continue;
    const r = toResult(buf, h.name);
    if (r) out.push(r);
  }
  return out;
}

function looksLikeOfficeZip(jszip) {
  const names = Object.keys(jszip.files || {});
  return names.some(
    (n) =>
      n === '[Content_Types].xml' ||
      n.startsWith('word/') ||
      n.startsWith('xl/') ||
      n.startsWith('ppt/'),
  );
}

async function extractAllFromZip(buffer, docType, max) {
  // eslint-disable-next-line global-require, import/no-extraneous-dependencies
  const JSZip = require('jszip');
  const zip = await JSZip.loadAsync(buffer);
  if (looksLikeOfficeZip(zip)) return [];

  const list = [];
  zip.forEach((relativePath, file) => {
    if (file.dir) return;
    list.push({ name: relativePath, file });
  });
  const ordered = orderCandidates(list, docType);

  const out = [];
  for (const h of ordered) {
    if (out.length >= max) break;
    const data = await h.file.async('nodebuffer');
    if (!data || data.length > MAX_EXTRACTED_BYTES) continue;
    const r = toResult(data, h.name);
    if (r) out.push(r);
  }
  return out;
}

/**
 * Если buffer — RAR/ZIP, вернуть все картинки/PDF внутри (до max).
 * Office ZIP (docx/xlsx) и архивы без картинок/PDF → пустой массив.
 * @returns {Promise<{ buffer: Buffer, fileName: string, mimeType: string }[]>}
 */
async function maybeExtractAllFromArchive(buffer, { docType, max = MAX_FILES_PER_ARCHIVE } = {}) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) return [];
  const magic = kindFromMagic(buffer);
  if (!magic) return [];

  try {
    if (magic.ext === '.rar' || magic.mimeType === 'application/vnd.rar') {
      return await extractAllFromRar(buffer, docType, max);
    }
    if (magic.ext === '.zip' || magic.mimeType === 'application/zip') {
      return await extractAllFromZip(buffer, docType, max);
    }
  } catch {
    return [];
  }
  return [];
}

module.exports = {
  maybeExtractAllFromArchive,
  MAX_EXTRACTED_BYTES,
  MAX_FILES_PER_ARCHIVE,
};
