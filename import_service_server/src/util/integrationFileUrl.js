const { toAbsoluteUrl } = require('./customsRequestDto');

const REQUEST_FILES_API_PREFIX = '/api/customs-requests/files/';

function normalize(v) {
  return String(v ?? '').trim();
}

/** Единый relative fileUrl для 1С и API (заявка + чат). */
function buildIntegrationFileUrl(storedName) {
  const safe = normalize(storedName);
  if (!safe) return '';
  return `${REQUEST_FILES_API_PREFIX}${safe}`;
}

/**
 * Из fileUrl (relative, absolute, legacy chat-attachments) — storedName на диске.
 */
function storedNameFromIntegrationFileUrl(fileUrl) {
  const raw = normalize(fileUrl);
  if (!raw) return '';

  const tryPath = (pathname) => {
    const p = normalize(pathname);
    const filesRe = /\/api\/customs-requests\/files\/([^/?#]+)$/i;
    const chatRe = /\/api\/chat-attachments\/([^/?#]+)$/i;
    const mFiles = filesRe.exec(p);
    if (mFiles) return decodeURIComponent(mFiles[1]);
    const mChat = chatRe.exec(p);
    if (mChat) return decodeURIComponent(mChat[1]);
    const base = p.split('/').pop() || '';
    if (/^r\d+_[\w.-]+$/i.test(base)) return base;
    if (/^o\d+_[\w.-]+$/i.test(base)) return base;
    return '';
  };

  if (/^https?:\/\//i.test(raw)) {
    try {
      return tryPath(new URL(raw).pathname);
    } catch {
      return '';
    }
  }

  if (raw.startsWith('/')) {
    return tryPath(raw);
  }

  if (/^r\d+_[\w.-]+$/i.test(raw)) {
    return raw;
  }

  return tryPath(`/${raw}`);
}

/** Нормализовать fileUrl к `/api/customs-requests/files/{storedName}`. */
function normalizeIntegrationFileUrl(fileUrl) {
  const stored = storedNameFromIntegrationFileUrl(fileUrl);
  if (stored) return buildIntegrationFileUrl(stored);
  return normalize(fileUrl);
}

function mapAttachmentsIntegrationFileUrls(attachments) {
  if (!Array.isArray(attachments)) return [];
  return attachments.map((a) => {
    if (!a || typeof a !== 'object') return a;
    const fileUrl = a.fileUrl != null ? normalizeIntegrationFileUrl(a.fileUrl) : a.fileUrl;
    return { ...a, fileUrl };
  });
}

function mapAttachmentsClientFileUrls(attachments, publicBaseUrl) {
  const base = String(publicBaseUrl || '').replace(/\/$/, '');
  return mapAttachmentsIntegrationFileUrls(attachments).map((a) => {
    if (!a || typeof a !== 'object') return a;
    const fileUrl =
      a.fileUrl != null && base ? toAbsoluteUrl(a.fileUrl, base) : a.fileUrl;
    return { ...a, fileUrl };
  });
}

/** Ответ upload для 1С (заявка и чат). */
function integrationFileUploadPayload(file, extra = {}) {
  const payload = {
    ok: true,
    file: {
      fileUrl: normalizeIntegrationFileUrl(file.fileUrl),
      fileName: file.fileName,
      mimeType: file.mimeType,
      fileSizeBytes: file.fileSizeBytes,
    },
  };
  if (file.docType != null && String(file.docType).trim()) {
    payload.file.docType = String(file.docType).trim();
  }
  if (file.previewUrl != null && String(file.previewUrl).trim()) {
    payload.file.previewUrl = normalizeIntegrationFileUrl(file.previewUrl);
  }
  if (file.replaced != null) {
    payload.file.replaced = Boolean(file.replaced);
  }
  for (const [key, value] of Object.entries(extra)) {
    if (value !== undefined) {
      payload[key] = value;
    }
  }
  return payload;
}

module.exports = {
  REQUEST_FILES_API_PREFIX,
  buildIntegrationFileUrl,
  storedNameFromIntegrationFileUrl,
  normalizeIntegrationFileUrl,
  mapAttachmentsIntegrationFileUrls,
  normalizeAttachmentsForIntegration: mapAttachmentsIntegrationFileUrls,
  mapAttachmentsClientFileUrls,
  integrationFileUploadPayload,
  sanitizeStoredName(fileUrlOrName) {
    const fromUrl = storedNameFromIntegrationFileUrl(fileUrlOrName);
    const raw = fromUrl || normalize(fileUrlOrName);
    return raw.replace(/[^a-zA-Z0-9._-]/g, '_') || 'file.bin';
  },
};
