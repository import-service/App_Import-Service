const crypto = require('crypto');
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const APK_DIR = path.join(process.cwd(), 'uploads', 'app-releases');
const APK_FILE_NAME = 'import-service-latest.apk';
const MANIFEST_FILE_NAME = 'manifest.json';
const APK_PATH = path.join(APK_DIR, APK_FILE_NAME);
const MANIFEST_PATH = path.join(APK_DIR, MANIFEST_FILE_NAME);

/** Макс. размер APK при загрузке (админ / скрипт). */
const LIMIT_APK_BYTES = 200 * 1024 * 1024;

function apkPath() {
  return APK_PATH;
}

function manifestPath() {
  return MANIFEST_PATH;
}

async function ensureDir() {
  await fsp.mkdir(APK_DIR, { recursive: true });
}

async function fileExists(p) {
  try {
    await fsp.access(p, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function sha256OfBuffer(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

async function sha256OfFile(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('error', reject);
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

/**
 * @param {{ versionCode: number, versionName?: string, publicBaseUrl?: string }} opts
 */
function buildPublicDto(manifest, publicBaseUrl) {
  const base = String(publicBaseUrl || '')
    .trim()
    .replace(/\/$/, '');
  const apkUrl = base
    ? `${base}/api/app/android-apk/download`
    : '/api/app/android-apk/download';
  return {
    available: true,
    versionCode: Number(manifest.versionCode) || 0,
    versionName: manifest.versionName ? String(manifest.versionName) : null,
    sha256: String(manifest.sha256 || ''),
    sizeBytes: Number(manifest.sizeBytes) || 0,
    updatedAt: manifest.updatedAt || null,
    apkUrl,
  };
}

async function readManifest() {
  if (!(await fileExists(MANIFEST_PATH)) || !(await fileExists(APK_PATH))) {
    return null;
  }
  try {
    const raw = await fsp.readFile(MANIFEST_PATH, 'utf8');
    const json = JSON.parse(raw);
    if (!json || typeof json !== 'object') return null;
    const versionCode = Number(json.versionCode);
    if (!Number.isFinite(versionCode) || versionCode < 1) return null;
    return json;
  } catch {
    return null;
  }
}

/**
 * Публичный / admin status.
 * @returns {Promise<{ available: false } | object>}
 */
async function getStatusDto(publicBaseUrl) {
  const manifest = await readManifest();
  if (!manifest) {
    return { available: false };
  }
  return buildPublicDto(manifest, publicBaseUrl);
}

/**
 * Сохранить APK (перезапись) + манифест.
 * @param {Buffer} buffer
 * @param {{ versionCode: number, versionName?: string }} meta
 */
async function publishApkBuffer(buffer, meta) {
  const versionCode = Number(meta.versionCode);
  if (!Number.isFinite(versionCode) || versionCode < 1) {
    throw new Error('VALIDATION_ERROR: versionCode обязателен (целое ≥ 1)');
  }
  if (!Buffer.isBuffer(buffer) || buffer.length < 1) {
    throw new Error('VALIDATION_ERROR: пустой APK');
  }
  if (buffer.length > LIMIT_APK_BYTES) {
    throw new Error(
      `VALIDATION_ERROR: APK больше ${Math.round(LIMIT_APK_BYTES / (1024 * 1024))} МБ`,
    );
  }
  // ZIP/APK magic
  if (buffer[0] !== 0x50 || buffer[1] !== 0x4b) {
    throw new Error('VALIDATION_ERROR: ожидается APK (ZIP)');
  }

  await ensureDir();
  const tmpPath = `${APK_PATH}.tmp`;
  await fsp.writeFile(tmpPath, buffer);
  await fsp.rename(tmpPath, APK_PATH);

  const sha256 = sha256OfBuffer(buffer);
  const versionName = String(meta.versionName || '').trim() || null;
  const manifest = {
    versionCode,
    versionName,
    sha256,
    sizeBytes: buffer.length,
    updatedAt: new Date().toISOString(),
    fileName: APK_FILE_NAME,
  };
  await fsp.writeFile(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  return manifest;
}

/**
 * Опубликовать уже лежащий на диске файл (после scp).
 * @param {string} sourcePath
 * @param {{ versionCode: number, versionName?: string }} meta
 */
async function publishApkFromPath(sourcePath, meta) {
  const versionCode = Number(meta.versionCode);
  if (!Number.isFinite(versionCode) || versionCode < 1) {
    throw new Error('VALIDATION_ERROR: versionCode обязателен (целое ≥ 1)');
  }
  const st = await fsp.stat(sourcePath);
  if (!st.isFile() || st.size < 1) {
    throw new Error('VALIDATION_ERROR: файл APK не найден');
  }
  if (st.size > LIMIT_APK_BYTES) {
    throw new Error(
      `VALIDATION_ERROR: APK больше ${Math.round(LIMIT_APK_BYTES / (1024 * 1024))} МБ`,
    );
  }

  await ensureDir();
  const absSource = path.resolve(sourcePath);
  if (absSource !== path.resolve(APK_PATH)) {
    await fsp.copyFile(absSource, APK_PATH);
  }

  const sha256 = await sha256OfFile(APK_PATH);
  const versionName = String(meta.versionName || '').trim() || null;
  const manifest = {
    versionCode,
    versionName,
    sha256,
    sizeBytes: st.size,
    updatedAt: new Date().toISOString(),
    fileName: APK_FILE_NAME,
  };
  await fsp.writeFile(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  return manifest;
}

module.exports = {
  LIMIT_APK_BYTES,
  APK_FILE_NAME,
  apkPath,
  manifestPath,
  ensureDir,
  getStatusDto,
  readManifest,
  publishApkBuffer,
  publishApkFromPath,
  fileExists,
};
