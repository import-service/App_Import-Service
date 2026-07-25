const path = require('path');
const fs = require('fs/promises');
const { v4: uuidv4 } = require('uuid');
const { resolveFileKind } = require('../util/fileKindDetect');
const { assertFileSizeAllowed, LIMIT_PHOTO_DOC_BYTES } = require('../constants/uploadLimits');
const { ensureDisplayFileName } = require('../util/displayFileName');

const CHAT_UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'chat-attachments');
const MAX_CHAT_ATTACHMENT_BYTES = LIMIT_PHOTO_DOC_BYTES;

function normalize(v) {
  return String(v ?? '').trim();
}

async function ensureChatUploadDir() {
  await fs.mkdir(CHAT_UPLOAD_ROOT, { recursive: true });
}

function buildChatFileUrl(storedName) {
  return `/api/chat-attachments/${storedName}`;
}

function absoluteChatFileUrl(fastify, storedName) {
  const rel = buildChatFileUrl(storedName);
  const base = String(fastify?.config?.publicBaseUrl || '').replace(/\/$/, '');
  if (!base) return rel;
  return `${base}${rel}`;
}

function isAllowedChatMime(mimeType) {
  const mt = normalize(mimeType).toLowerCase();
  return mt.startsWith('image/') || mt === 'application/pdf';
}

/**
 * Сохранить вложение чата на диск.
 * @returns {{ storedName, fileName, mimeType, fileSizeBytes, fileUrl, absoluteFileUrl }}
 */
async function saveChatAttachment(fastify, { requestId, buffer, clientFileName, mimeType }) {
  await ensureChatUploadDir();
  const kind = resolveFileKind({
    buffer,
    clientFileName,
    mimeType,
  });
  const resolvedMime = kind.mimeType || normalize(mimeType) || 'application/octet-stream';
  if (!isAllowedChatMime(resolvedMime)) {
    const err = new Error('Допустимы только изображения и PDF');
    err.code = 'VALIDATION_ERROR';
    throw err;
  }
  assertFileSizeAllowed(buffer.length, null, resolvedMime);
  if (buffer.length > MAX_CHAT_ATTACHMENT_BYTES) {
    const err = new Error(`Файл больше ${Math.round(MAX_CHAT_ATTACHMENT_BYTES / (1024 * 1024))} МБ`);
    err.code = 'VALIDATION_ERROR';
    throw err;
  }

  const ext = kind.ext.startsWith('.') ? kind.ext : `.${kind.ext}`;
  const storedName = `r${Number(requestId)}_${uuidv4()}${ext}`;
  const displayName = ensureDisplayFileName({
    mimeType: resolvedMime,
    clientFileName: clientFileName || `attachment${ext}`,
  });
  const absPath = path.join(CHAT_UPLOAD_ROOT, storedName);
  await fs.writeFile(absPath, buffer);

  const fileUrl = buildChatFileUrl(storedName);
  return {
    storedName,
    fileName: displayName,
    mimeType: resolvedMime,
    fileSizeBytes: buffer.length,
    fileUrl,
    absoluteFileUrl: absoluteChatFileUrl(fastify, storedName),
  };
}

function chatAttachmentDiskPath(storedName) {
  const safe = normalize(storedName).replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safe || safe !== normalize(storedName)) return null;
  return path.join(CHAT_UPLOAD_ROOT, safe);
}

function requestIdFromChatStoredName(storedName) {
  const m = /^r(\d+)_/.exec(normalize(storedName));
  return m ? Number(m[1]) : 0;
}

module.exports = {
  CHAT_UPLOAD_ROOT,
  MAX_CHAT_ATTACHMENT_BYTES,
  ensureChatUploadDir,
  saveChatAttachment,
  chatAttachmentDiskPath,
  requestIdFromChatStoredName,
  buildChatFileUrl,
  absoluteChatFileUrl,
  isAllowedChatMime,
};
