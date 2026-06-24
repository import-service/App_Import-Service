const fs = require('fs/promises');
const path = require('path');
const { shouldGeneratePreview } = require('../constants/uploadLimits');

const PREVIEW_MAX_EDGE = 1200;
const PREVIEW_JPEG_QUALITY = 80;

let sharpModule;
function getSharp() {
  if (sharpModule !== undefined) return sharpModule;
  try {
    // eslint-disable-next-line global-require, import/no-extraneous-dependencies
    sharpModule = require('sharp');
  } catch {
    sharpModule = null;
  }
  return sharpModule;
}

/**
 * @returns {Promise<Buffer | null>}
 */
async function generateImagePreviewBuffer(sourceBuffer, mimeType, docType) {
  if (!shouldGeneratePreview(docType, mimeType)) return null;
  const sharp = getSharp();
  if (!sharp) return null;

  try {
    const previewBuffer = await sharp(sourceBuffer)
      .rotate()
      .resize({
        width: PREVIEW_MAX_EDGE,
        height: PREVIEW_MAX_EDGE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: PREVIEW_JPEG_QUALITY, mozjpeg: true })
      .toBuffer();
    return previewBuffer.length ? previewBuffer : null;
  } catch {
    return null;
  }
}

async function writePreviewFile(uploadRoot, previewStoredName, previewBuffer) {
  const previewPath = path.join(uploadRoot, previewStoredName);
  await fs.writeFile(previewPath, previewBuffer);
}

async function unlinkIfExists(uploadRoot, storedName) {
  if (!storedName) return;
  try {
    await fs.unlink(path.join(uploadRoot, storedName));
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
}

module.exports = {
  generateImagePreviewBuffer,
  writePreviewFile,
  unlinkIfExists,
};
