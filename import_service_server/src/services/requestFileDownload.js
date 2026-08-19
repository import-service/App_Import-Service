const fs = require('fs/promises');
const path = require('path');
const { isIntegrationBearerRequest } = require('../util/integrationAuth');
const { isMpJwtRequest, mpOrganizationId } = require('../util/requestOrganizationAccess');
const { getPublicBaseUrl } = require('../util/customsRequestDto');
const {
  buildIntegrationFileUrl,
  storedNameFromIntegrationFileUrl,
} = require('../util/integrationFileUrl');
const {
  chatAttachmentDiskPath,
  requestIdFromChatStoredName,
  organizationIdFromChatStoredName,
} = require('./chatAttachmentStorage');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads', 'customs-requests');

function normalize(v) {
  return String(v ?? '').trim();
}

function sanitizeFileName(fileName) {
  return normalize(fileName).replace(/[^a-zA-Z0-9._-]/g, '_') || 'file.bin';
}

function mimeFromStoredName(storedName, fallback = 'application/octet-stream') {
  const ext = normalize(storedName).toLowerCase();
  if (ext.endsWith('.pdf')) return 'application/pdf';
  if (ext.endsWith('.png')) return 'image/png';
  if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
  if (ext.endsWith('.webp')) return 'image/webp';
  if (ext.endsWith('.gif')) return 'image/gif';
  if (ext.endsWith('.mp4')) return 'video/mp4';
  return fallback;
}

function buildFileDownloadError(fastify, request, {
  error,
  message,
  storedName,
  requestedStoredName,
  fileKind = null,
  details = null,
}) {
  const safeStoredName = normalize(storedName) || 'file.bin';
  const fileUrl = buildIntegrationFileUrl(safeStoredName);
  const base = getPublicBaseUrl(fastify, request);
  const absoluteFileUrl = base
    ? `${String(base).replace(/\/$/, '')}${fileUrl}`
    : fileUrl;
  const payload = {
    error,
    message,
    storedName: safeStoredName,
    requestedStoredName: normalize(requestedStoredName) || safeStoredName,
    fileUrl,
    absoluteFileUrl,
  };
  if (fileKind) payload.fileKind = fileKind;
  if (details) payload.details = details;
  if (payload.requestedStoredName !== payload.storedName) {
    payload.storedNameSanitized = true;
  }
  return payload;
}

function sendFileDownloadError(reply, fastify, request, statusCode, fields) {
  return reply.code(statusCode).send(buildFileDownloadError(fastify, request, fields));
}

async function assertMpCanAccessChatFile(pool, requestId, orgId) {
  if (!requestId || orgId == null) {
    return { ok: false, reason: 'missing_org_or_request' };
  }
  const [rows] = await pool.query(
    `SELECT id, organization_id, deleted_at, external_1c_id
     FROM customs_requests
     WHERE id = ?
     LIMIT 1`,
    [requestId],
  );
  if (!rows.length || rows[0].deleted_at) {
    return { ok: false, reason: 'request_not_found' };
  }
  if (Number(rows[0].organization_id) !== orgId) {
    return { ok: false, reason: 'wrong_organization' };
  }
  if (!rows[0].external_1c_id) {
    return { ok: false, reason: 'chat_not_available' };
  }
  return { ok: true, row: rows[0] };
}

/**
 * GET /api/customs-requests/files/:storedName — файлы заявки и вложения чата.
 */
async function serveRequestOrChatFile(fastify, request, reply, uploadRoot = UPLOAD_ROOT) {
  const requestedStoredName = normalize(request.params.storedName);
  const storedName = sanitizeFileName(requestedStoredName);
  const requestFilePath = path.join(uploadRoot, storedName);

  try {
    const [rows] = await fastify.pool.query(
      `SELECT f.mime_type, f.stored_name, f.preview_stored_name, r.organization_id
       FROM customs_request_files f
       INNER JOIN customs_requests r ON r.id = f.request_id AND r.deleted_at IS NULL
       WHERE f.deleted_at IS NULL
         AND (f.stored_name = ? OR f.preview_stored_name = ?)
       LIMIT 1`,
      [storedName, storedName],
    );

    if (rows.length) {
      if (isMpJwtRequest(request)) {
        const orgId = mpOrganizationId(request);
        if (!orgId || Number(rows[0].organization_id) !== orgId) {
          return sendFileDownloadError(reply, fastify, request, 404, {
            error: 'FILE_ACCESS_DENIED',
            message: 'Нет доступа к файлу заявки (другая организация или не авторизован)',
            storedName,
            requestedStoredName,
            fileKind: 'request',
            details: 'access_denied_for_organization',
          });
        }
      }

      const isPreview =
        rows[0].preview_stored_name &&
        String(rows[0].preview_stored_name) === storedName;
      const mimeType = isPreview
        ? 'image/jpeg'
        : rows[0].mime_type || 'application/octet-stream';

      let stat;
      try {
        stat = await fs.stat(requestFilePath);
      } catch (e) {
        if (e.code === 'ENOENT') {
          return sendFileDownloadError(reply, fastify, request, 404, {
            error: 'FILE_NOT_ON_DISK',
            message: 'Запись о файле заявки есть, но файл отсутствует на диске сервера',
            storedName,
            requestedStoredName,
            fileKind: 'request',
            details: 'database_record_without_binary',
          });
        }
        throw e;
      }

      if (!stat.isFile()) {
        return sendFileDownloadError(reply, fastify, request, 404, {
          error: 'FILE_NOT_ON_DISK',
          message: 'Путь на диске не является файлом',
          storedName,
          requestedStoredName,
          fileKind: 'request',
          details: 'not_a_regular_file',
        });
      }

      return reply.type(mimeType).send(await fs.readFile(requestFilePath));
    }

    const chatDiskPath = chatAttachmentDiskPath(storedName);
    if (!chatDiskPath) {
      return sendFileDownloadError(reply, fastify, request, 404, {
        error: 'INVALID_STORED_NAME',
        message: 'Некорректное имя файла (не найдено в БД заявки и не похоже на вложение чата)',
        storedName,
        requestedStoredName,
        fileKind: null,
        details: 'invalid_stored_name',
      });
    }

    if (!isIntegrationBearerRequest(request) && isMpJwtRequest(request)) {
      const orgId = mpOrganizationId(request);
      const chatOrgId = organizationIdFromChatStoredName(storedName);
      if (chatOrgId > 0) {
        if (orgId == null || Number(orgId) !== chatOrgId) {
          return sendFileDownloadError(reply, fastify, request, 404, {
            error: 'CHAT_FILE_ACCESS_DENIED',
            message: 'Нет доступа к вложению общего чата',
            storedName,
            requestedStoredName,
            fileKind: 'chat',
            details: 'wrong_organization',
          });
        }
      } else {
        const chatRequestId = requestIdFromChatStoredName(storedName);
        const access = await assertMpCanAccessChatFile(fastify.pool, chatRequestId, orgId);
        if (!access.ok) {
          const reasonMessages = {
            missing_org_or_request: 'Не удалось проверить доступ к вложению чата',
            request_not_found: 'Заявка для вложения чата не найдена',
            wrong_organization: 'Нет доступа к вложению чата (другая организация)',
            chat_not_available: 'Чат по этой заявке недоступен',
          };
          return sendFileDownloadError(reply, fastify, request, 404, {
            error: 'CHAT_FILE_ACCESS_DENIED',
            message: reasonMessages[access.reason] || 'Нет доступа к вложению чата',
            storedName,
            requestedStoredName,
            fileKind: 'chat',
            details: access.reason,
          });
        }
      }
    }

    let stat;
    try {
      stat = await fs.stat(chatDiskPath);
    } catch (e) {
      if (e.code === 'ENOENT') {
        return sendFileDownloadError(reply, fastify, request, 404, {
          error: 'FILE_NOT_ON_DISK',
          message: 'Вложение чата: файл отсутствует на диске сервера',
          storedName,
          requestedStoredName,
          fileKind: 'chat',
          details: 'chat_attachment_missing_on_disk',
        });
      }
      throw e;
    }

    if (!stat.isFile()) {
      return sendFileDownloadError(reply, fastify, request, 404, {
        error: 'FILE_NOT_ON_DISK',
        message: 'Путь вложения чата на диске не является файлом',
        storedName,
        requestedStoredName,
        fileKind: 'chat',
        details: 'not_a_regular_file',
      });
    }

    const contentType = mimeFromStoredName(storedName);
    return reply.type(contentType).send(await fs.readFile(chatDiskPath));
  } catch (e) {
    if (e.code === 'ENOENT') {
      return sendFileDownloadError(reply, fastify, request, 404, {
        error: 'FILE_NOT_FOUND',
        message: 'Файл не найден на сервере',
        storedName,
        requestedStoredName,
        fileKind: null,
        details: 'unexpected_enoent',
      });
    }
    fastify.log.error(e);
    return reply.code(500).send({
      error: 'INTERNAL_ERROR',
      message: 'Внутренняя ошибка при отдаче файла',
      storedName,
      requestedStoredName,
      fileUrl: buildIntegrationFileUrl(storedName),
    });
  }
}

/** Legacy alias: /api/chat-attachments/:storedName */
async function serveChatFileLegacyAlias(fastify, request, reply, uploadRoot = UPLOAD_ROOT) {
  const fromParam = sanitizeFileName(request.params.storedName);
  const fromUrl = storedNameFromIntegrationFileUrl(request.params.storedName);
  const storedName = fromUrl || fromParam;
  request.params.storedName = storedName;
  return serveRequestOrChatFile(fastify, request, reply, uploadRoot);
}

module.exports = {
  UPLOAD_ROOT,
  serveRequestOrChatFile,
  serveChatFileLegacyAlias,
  sanitizeFileName,
  buildFileDownloadError,
};
