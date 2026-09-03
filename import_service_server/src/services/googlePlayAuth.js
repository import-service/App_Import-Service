const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');

const ANDROID_PUBLISHER_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function resolveServiceAccountPath(cfg, serverRoot) {
  const rawPath = String(cfg.googlePlayServiceAccountPath || '').trim();
  if (!rawPath) return null;
  if (path.isAbsolute(rawPath)) return rawPath;
  return path.join(serverRoot || process.cwd(), rawPath);
}

function createAndroidPublisherClient(keyFilePath) {
  if (!keyFilePath || !fs.existsSync(keyFilePath)) {
    throw new Error('Google Play service account key file not found');
  }
  const auth = new google.auth.GoogleAuth({
    keyFile: keyFilePath,
    scopes: [ANDROID_PUBLISHER_SCOPE],
  });
  return google.androidpublisher({ version: 'v3', auth });
}

function parseVersionNameFromRelease(release) {
  const releaseName = String(release?.name || '').trim();
  if (!releaseName) return null;
  const match = releaseName.match(/([0-9]+(?:\.[0-9]+)+)/);
  return match ? match[1] : null;
}

function pickLatestProductionRelease(releases) {
  const list = Array.isArray(releases) ? releases : [];
  if (!list.length) return null;

  const preferred = list.filter((release) => {
    const status = String(release?.status || '').toLowerCase();
    return status === 'completed' || status === 'inprogress';
  });
  const pool = preferred.length ? preferred : list;

  let best = pool[0];
  let bestCode = -1;
  for (const release of pool) {
    const codes = (release.versionCodes || [])
      .map((value) => Number(value))
      .filter(Number.isFinite);
    const maxCode = codes.length ? Math.max(...codes) : -1;
    if (maxCode >= bestCode) {
      bestCode = maxCode;
      best = release;
    }
  }
  return best;
}

async function fetchProductionVersion(packageName, keyFilePath) {
  const androidpublisher = createAndroidPublisherClient(keyFilePath);
  const { data: editData } = await androidpublisher.edits.insert({ packageName });
  const editId = editData?.id;
  if (!editId) {
    throw new Error('Google Play API: edit id missing');
  }

  try {
    const { data: trackData } = await androidpublisher.edits.tracks.get({
      packageName,
      editId,
      track: 'production',
    });

    const release = pickLatestProductionRelease(trackData?.releases);
    if (!release) {
      throw new Error('Google Play API: no production releases');
    }

    const versionCodes = (release.versionCodes || [])
      .map((value) => Number(value))
      .filter(Number.isFinite);
    const versionCode = versionCodes.length ? Math.max(...versionCodes) : null;
    const versionName = parseVersionNameFromRelease(release);

    if (versionCode == null && !versionName) {
      throw new Error('Google Play API: version not found in production track');
    }

    return { versionName, versionCode };
  } finally {
    try {
      await androidpublisher.edits.delete({ packageName, editId });
    } catch {
      // best-effort cleanup
    }
  }
}

module.exports = {
  resolveServiceAccountPath,
  fetchProductionVersion,
};
