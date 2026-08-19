const { v4: uuidv4 } = require('uuid');
const fs = require('fs/promises');
const { createOrgInboundMessage } = require('./orgChatOps');
const { sendPlainEmail, escapeHtml } = require('./emailNotification');
const {
  saveChatAttachment,
  chatAttachmentDiskPath,
} = require('./chatAttachmentStorage');
const { storedNameFromIntegrationFileUrl } = require('../util/integrationFileUrl');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function looksLikeEmail(value) {
  return EMAIL_RE.test(String(value || '').trim());
}

async function listLiveOrganizations(pool) {
  const [rows] = await pool.query(
    `SELECT id, id_1c, login, company_name
     FROM organizations
     WHERE deleted_at IS NULL
     ORDER BY id ASC`,
  );
  return rows;
}

async function saveBroadcastAttachment(fastify, { buffer, clientFileName, mimeType }) {
  return saveChatAttachment(fastify, {
    broadcast: true,
    buffer,
    clientFileName,
    mimeType,
  });
}

async function sendBroadcast(fastify, {
  text,
  attachments = [],
  senderName = 'Рассылка',
  source = 'admin',
  batchId = null,
  fileBuffer = null,
  fileName = null,
  fileMime = null,
}) {
  const bodyText = String(text || '').trim();
  const attsIn = Array.isArray(attachments) ? attachments.filter((a) => a && a.fileUrl) : [];
  let savedFile = null;

  if (fileBuffer && fileBuffer.length) {
    savedFile = await saveBroadcastAttachment(fastify, {
      buffer: fileBuffer,
      clientFileName: fileName,
      mimeType: fileMime,
    });
    attsIn.push({
      fileUrl: savedFile.fileUrl,
      fileName: savedFile.fileName,
      mimeType: savedFile.mimeType,
    });
  }

  if (!bodyText && !attsIn.length) {
    const e = new Error('VALIDATION_ERROR');
    e.code = 'VALIDATION_ERROR';
    e.messageRu = 'Нужен текст или файл';
    throw e;
  }

  const orgs = await listLiveOrganizations(fastify.pool);
  const runId = String(batchId || uuidv4());
  const sender = String(senderName || 'Рассылка').trim() || 'Рассылка';
  const appName = fastify.config?.smtp?.appName || 'Импорт Сервис';
  const subject = `${appName}: сообщение`;

  const mailAttachments = [];
  if (savedFile) {
    const disk = chatAttachmentDiskPath(savedFile.storedName);
    if (disk) {
      try {
        const content = await fs.readFile(disk);
        mailAttachments.push({
          filename: savedFile.fileName,
          content,
          contentType: savedFile.mimeType,
        });
      } catch (e) {
        fastify.log.warn({ err: e.message }, 'broadcast: could not attach file to email');
      }
    }
  } else if (attsIn.length) {
    const stored = storedNameFromIntegrationFileUrl(attsIn[0].fileUrl);
    const disk = stored ? chatAttachmentDiskPath(stored) : null;
    if (disk) {
      try {
        const content = await fs.readFile(disk);
        mailAttachments.push({
          filename: attsIn[0].fileName || stored,
          content,
          contentType: attsIn[0].mimeType || 'application/octet-stream',
        });
      } catch (e) {
        fastify.log.warn({ err: e.message }, 'broadcast: could not attach existing file to email');
      }
    }
  }

  const html = `<p>${escapeHtml(bodyText).replace(/\n/g, '<br>')}</p>
<p style="color:#6b7280;font-size:13px">Сообщение также в общем чате приложения «${escapeHtml(appName)}».</p>`;

  let chatOk = 0;
  let chatFail = 0;
  let emailOk = 0;
  let emailSkip = 0;
  let emailFail = 0;

  for (const org of orgs) {
    const orgId = Number(org.id);
    try {
      await createOrgInboundMessage(fastify, {
        organizationId: orgId,
        id1c: org.id_1c || null,
        message1cId: `broadcast-${runId}-org-${orgId}`,
        text: bodyText,
        attachments: attsIn,
        senderName: sender,
        sender1cId: source === 'integration' ? 'broadcast' : 'admin-broadcast',
      });
      chatOk += 1;
    } catch (e) {
      chatFail += 1;
      fastify.log.warn(
        { orgId, err: e.message },
        'broadcast: chat delivery failed',
      );
    }

    const to = String(org.login || '').trim();
    if (!looksLikeEmail(to)) {
      emailSkip += 1;
      continue;
    }
    const mail = await sendPlainEmail(
      fastify.config.smtp,
      {
        to,
        subject,
        text: bodyText || (mailAttachments.length ? 'См. вложение' : ''),
        html,
        attachments: mailAttachments.length ? mailAttachments : undefined,
      },
      fastify.log,
    );
    if (mail.success) emailOk += 1;
    else emailFail += 1;
  }

  return {
    ok: true,
    batchId: runId,
    source,
    organizations: orgs.length,
    chatOk,
    chatFail,
    emailOk,
    emailSkip,
    emailFail,
    attachment: savedFile
      ? { fileUrl: savedFile.fileUrl, fileName: savedFile.fileName, mimeType: savedFile.mimeType }
      : (attsIn[0] || null),
  };
}

module.exports = {
  sendBroadcast,
  saveBroadcastAttachment,
  listLiveOrganizations,
};
