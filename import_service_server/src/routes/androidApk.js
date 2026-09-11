const fs = require('fs');
const {
  LIMIT_APK_BYTES,
  APK_FILE_NAME,
  apkPath,
  getStatusDto,
  publishApkBuffer,
  fileExists,
} = require('../services/androidApkRelease');

function multipartFieldValue(fields, name) {
  const v = fields?.[name];
  if (v == null) return '';
  if (typeof v === 'string') return v.trim();
  if (typeof v === 'object' && v.value != null) return String(v.value).trim();
  return String(v).trim();
}

module.exports = async function androidApkRoutes(fastify) {
  const publicBase = () => fastify.config.publicBaseUrl || '';

  /** Публичный манифест: версия / sha256 / URL скачивания. */
  fastify.get('/app/android-apk', async (_request, reply) => {
    const dto = await getStatusDto(publicBase());
    return reply.send(dto);
  });

  /** Публичное скачивание одного APK (перезаписываемого). */
  fastify.get('/app/android-apk/download', async (_request, reply) => {
    const pathToApk = apkPath();
    if (!(await fileExists(pathToApk))) {
      return reply.code(404).send({ error: 'APK_NOT_FOUND' });
    }
    const stat = await fs.promises.stat(pathToApk);
    reply.header('Content-Type', 'application/vnd.android.package-archive');
    reply.header(
      'Content-Disposition',
      `attachment; filename="${APK_FILE_NAME}"`,
    );
    reply.header('Content-Length', String(stat.size));
    reply.header('Cache-Control', 'no-store');
    return reply.send(fs.createReadStream(pathToApk));
  });

  fastify.get(
    '/admin/android-apk',
    { onRequest: [fastify.authenticateAdmin] },
    async (_request, reply) => {
      const dto = await getStatusDto(publicBase());
      return reply.send(dto);
    },
  );

  /**
   * Загрузка APK (перезапись).
   * multipart: file (обязательно), versionCode (обязательно), versionName (опционально).
   */
  fastify.post(
    '/admin/android-apk',
    { onRequest: [fastify.authenticateAdmin] },
    async (request, reply) => {
      const ct = String(request.headers['content-type'] || '');
      if (!ct.includes('multipart/form-data')) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен multipart: file, versionCode',
        });
      }

      let fileBuffer = null;
      let fileName = '';
      const fields = {};

      try {
        const parts = request.parts({
          limits: { fileSize: LIMIT_APK_BYTES, files: 1 },
        });
        for await (const part of parts) {
          if (part.type === 'file') {
            if (part.fieldname !== 'file') {
              await part.toBuffer();
              continue;
            }
            fileName = part.filename || APK_FILE_NAME;
            fileBuffer = await part.toBuffer();
          } else {
            fields[part.fieldname] = part.value;
          }
        }
      } catch (e) {
        if (e && (e.code === 'FST_REQ_FILE_TOO_LARGE' || /limit/i.test(String(e.message)))) {
          return reply.code(413).send({
            error: 'APK_TOO_LARGE',
            message: `APK больше ${Math.round(LIMIT_APK_BYTES / (1024 * 1024))} МБ`,
          });
        }
        throw e;
      }

      if (!fileBuffer || !fileBuffer.length) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Нужен multipart: file',
        });
      }

      const versionCodeRaw = multipartFieldValue(fields, 'versionCode');
      const versionName = multipartFieldValue(fields, 'versionName');
      const versionCode = Number(versionCodeRaw);
      if (!Number.isFinite(versionCode) || versionCode < 1) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'versionCode обязателен (целое ≥ 1, как buildNumber +N)',
        });
      }

      try {
        const manifest = await publishApkBuffer(fileBuffer, {
          versionCode,
          versionName: versionName || undefined,
        });
        const dto = await getStatusDto(publicBase());
        fastify.log.info(
          {
            versionCode: manifest.versionCode,
            sizeBytes: manifest.sizeBytes,
            fileName,
          },
          'android apk published',
        );
        return reply.send({ ok: true, ...dto });
      } catch (e) {
        const msg = e && e.message ? String(e.message) : 'publish failed';
        if (msg.startsWith('VALIDATION_ERROR')) {
          return reply.code(400).send({ error: 'VALIDATION_ERROR', message: msg });
        }
        throw e;
      }
    },
  );
};
