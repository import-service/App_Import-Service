#!/usr/bin/env node
/**
 * Опубликовать APK уже лежащий на диске сервера (после scp).
 * Usage:
 *   node scripts/publish-android-apk.js --file /path/to.apk --versionCode 34 [--versionName 1.0.34] [--changelog "..."] [--changelogBase64 ...]
 */
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const {
  apkPath,
  publishApkFromPath,
  getStatusDto,
} = require('../src/services/androidApkRelease');
const { notifyAndroidApkPublished } = require('../src/services/emailNotification');
const config = require('../src/config');

function argValue(name) {
  const i = process.argv.indexOf(name);
  if (i < 0 || i + 1 >= process.argv.length) return null;
  return process.argv[i + 1];
}

function resolveChangelog() {
  const b64 = argValue('--changelogBase64');
  if (b64) {
    try {
      return Buffer.from(b64, 'base64').toString('utf8');
    } catch {
      return '';
    }
  }
  return argValue('--changelog') || '';
}

async function main() {
  const versionCode = Number(argValue('--versionCode'));
  const versionName = argValue('--versionName') || undefined;
  const changelog = resolveChangelog();
  const file = argValue('--file') || apkPath();

  if (!Number.isFinite(versionCode) || versionCode < 1) {
    console.error('Need --versionCode <int>');
    process.exit(1);
  }

  const manifest = await publishApkFromPath(file, {
    versionCode,
    versionName,
    changelog,
  });
  const publicBase = process.env.PUBLIC_BASE_URL || config.publicBaseUrl || '';
  const dto = await getStatusDto(publicBase);
  console.log(JSON.stringify({ ok: true, manifest, status: dto }, null, 2));

  try {
    const mail = await notifyAndroidApkPublished(
      config.smtp,
      {
        versionCode: dto.versionCode,
        versionName: dto.versionName,
        apkUrl: dto.apkUrl,
        sizeBytes: dto.sizeBytes ?? dto.fileSizeBytes,
        changelog: dto.changelog || changelog || '',
      },
      console,
    );
    if (!mail?.success) {
      console.error('EMAIL_WARN', mail?.error || 'send failed');
    } else {
      console.log('EMAIL_OK', mail.messageId || '');
    }
  } catch (e) {
    console.error('EMAIL_WARN', e.message || e);
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
