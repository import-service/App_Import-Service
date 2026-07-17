const path = require('path');

function normalize(v) {
  return String(v ?? '').trim();
}

/** @returns {{ ext: string, mimeType: string } | null} */
function kindFromExtension(fileName) {
  const ext = path.extname(normalize(fileName)).toLowerCase();
  if (!ext || ext.length > 12) return null;
  const map = {
    '.jpg': { ext: '.jpg', mimeType: 'image/jpeg' },
    '.jpeg': { ext: '.jpg', mimeType: 'image/jpeg' },
    '.png': { ext: '.png', mimeType: 'image/png' },
    '.webp': { ext: '.webp', mimeType: 'image/webp' },
    '.gif': { ext: '.gif', mimeType: 'image/gif' },
    '.heic': { ext: '.heic', mimeType: 'image/heic' },
    '.bmp': { ext: '.bmp', mimeType: 'image/bmp' },
    '.pdf': { ext: '.pdf', mimeType: 'application/pdf' },
    '.mp4': { ext: '.mp4', mimeType: 'video/mp4' },
    '.mov': { ext: '.mov', mimeType: 'video/quicktime' },
    '.webm': { ext: '.webm', mimeType: 'video/webm' },
    '.mkv': { ext: '.mkv', mimeType: 'video/x-matroska' },
    '.avi': { ext: '.avi', mimeType: 'video/x-msvideo' },
    '.m4v': { ext: '.m4v', mimeType: 'video/x-m4v' },
    '.mp3': { ext: '.mp3', mimeType: 'audio/mpeg' },
    '.m4a': { ext: '.m4a', mimeType: 'audio/mp4' },
    '.wav': { ext: '.wav', mimeType: 'audio/wav' },
    '.aac': { ext: '.aac', mimeType: 'audio/aac' },
    '.ogg': { ext: '.ogg', mimeType: 'audio/ogg' },
  };
  return map[ext] || null;
}

/** @returns {{ ext: string, mimeType: string } | null} */
function kindFromMagic(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) return null;
  // JPEG
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { ext: '.jpg', mimeType: 'image/jpeg' };
  }
  // PNG
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return { ext: '.png', mimeType: 'image/png' };
  }
  // GIF
  if (buffer.slice(0, 3).toString('ascii') === 'GIF') {
    return { ext: '.gif', mimeType: 'image/gif' };
  }
  // PDF
  if (buffer.slice(0, 4).toString('ascii') === '%PDF') {
    return { ext: '.pdf', mimeType: 'application/pdf' };
  }
  // RAR (Rar!\x1a\x07)
  if (buffer.slice(0, 4).toString('ascii') === 'Rar!') {
    return { ext: '.rar', mimeType: 'application/vnd.rar' };
  }
  // ZIP / DOCX / XLSX (PK)
  if (buffer[0] === 0x50 && buffer[1] === 0x4b && (buffer[2] === 0x03 || buffer[2] === 0x05 || buffer[2] === 0x07)) {
    return { ext: '.zip', mimeType: 'application/zip' };
  }
  // WEBP: RIFF....WEBP
  if (
    buffer.length >= 12 &&
    buffer.slice(0, 4).toString('ascii') === 'RIFF' &&
    buffer.slice(8, 12).toString('ascii') === 'WEBP'
  ) {
    return { ext: '.webp', mimeType: 'image/webp' };
  }
  // MP4 / ISO BMFF (ftyp)
  if (buffer.length >= 8 && buffer.slice(4, 8).toString('ascii') === 'ftyp') {
    return { ext: '.mp4', mimeType: 'video/mp4' };
  }
  return null;
}

function mimeFromExt(ext) {
  const e = (ext || '').toLowerCase();
  if (e === '.jpg' || e === '.jpeg') return 'image/jpeg';
  if (e === '.png') return 'image/png';
  if (e === '.webp') return 'image/webp';
  if (e === '.gif') return 'image/gif';
  if (e === '.pdf') return 'application/pdf';
  if (e === '.mp4') return 'video/mp4';
  if (e.startsWith('.') && e.length <= 12) return null;
  return null;
}

/**
 * Приоритет: magic bytes → расширение fileName → заявленный mime → octet-stream/.bin
 * @returns {{ mimeType: string, ext: string, detectedFrom: 'magic'|'filename'|'mime'|'fallback' }}
 */
function resolveFileKind({ buffer, clientFileName, mimeType }) {
  const fromMagic = kindFromMagic(buffer);
  if (fromMagic) {
    return { ...fromMagic, detectedFrom: 'magic' };
  }

  const fromName = kindFromExtension(clientFileName);
  if (fromName) {
    return { ...fromName, detectedFrom: 'filename' };
  }

  const mt = normalize(mimeType).toLowerCase();
  if (mt && mt !== 'application/octet-stream') {
    if (mt === 'image/jpeg' || mt === 'image/jpg') {
      return { ext: '.jpg', mimeType: 'image/jpeg', detectedFrom: 'mime' };
    }
    if (mt === 'image/png') {
      return { ext: '.png', mimeType: 'image/png', detectedFrom: 'mime' };
    }
    if (mt === 'image/webp') {
      return { ext: '.webp', mimeType: 'image/webp', detectedFrom: 'mime' };
    }
    if (mt === 'application/pdf') {
      return { ext: '.pdf', mimeType: 'application/pdf', detectedFrom: 'mime' };
    }
    if (mt === 'video/mp4') {
      return { ext: '.mp4', mimeType: 'video/mp4', detectedFrom: 'mime' };
    }
    if (mt.startsWith('image/')) {
      return { ext: '.bin', mimeType: mt, detectedFrom: 'mime' };
    }
    if (mt.startsWith('video/')) {
      return { ext: '.mp4', mimeType: mt, detectedFrom: 'mime' };
    }
    if (mt.startsWith('audio/')) {
      return { ext: '.m4a', mimeType: mt, detectedFrom: 'mime' };
    }
  }

  return {
    ext: '.bin',
    mimeType: mt || 'application/octet-stream',
    detectedFrom: 'fallback',
  };
}

module.exports = {
  kindFromExtension,
  kindFromMagic,
  mimeFromExt,
  resolveFileKind,
};
