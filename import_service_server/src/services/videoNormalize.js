const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const { randomUUID } = require('crypto');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

const FFMPEG_TIMEOUT_MS = 5 * 60 * 1000;

function whichBin(name) {
  return name;
}

/**
 * Нужно ли перекодировать (High Profile / битый mux / нет AAC и т.п.).
 * При сомнении — да (безопасный mp4 для OEM MediaCodec).
 */
function needsVideoNormalize(probe) {
  if (!probe || typeof probe !== 'object') return true;
  const streams = Array.isArray(probe.streams) ? probe.streams : [];
  const video = streams.find((s) => s.codec_type === 'video');
  const audio = streams.find((s) => s.codec_type === 'audio');
  if (!video) return true;
  const codec = String(video.codec_name || '').toLowerCase();
  if (codec !== 'h264') return true;
  const profile = String(video.profile || '').toLowerCase();
  // Baseline / Constrained Baseline / Main — ок; High и выше — часто валят Xiaomi MediaCodec.
  if (profile.includes('high') || profile.includes('predictive')) return true;
  const pix = String(video.pix_fmt || '').toLowerCase();
  if (pix && pix !== 'yuv420p') return true;
  if (!audio) return true;
  const acodec = String(audio.codec_name || '').toLowerCase();
  if (acodec !== 'aac') return true;
  if (Number(audio.channels) !== 2) return true;
  const width = Number(video.width) || 0;
  const height = Number(video.height) || 0;
  // MediaCodec на части OEM падает, если сторона не кратна 16.
  if (width % 16 !== 0 || height % 16 !== 0) return true;
  const fmt = probe.format || {};
  const formatName = String(fmt.format_name || '').toLowerCase();
  if (formatName && !formatName.includes('mp4') && !formatName.includes('mov')) return true;
  if (videoHasOddOrientation(video)) return true;
  const sar = String(video.sample_aspect_ratio || '');
  if (sar && sar !== '1:1' && sar !== 'N/A' && sar !== '0:1') return true;
  return false;
}

/** Поворот в метаданных, а не в пикселях — на ПК картинка «лёжа». */
function videoHasOddOrientation(video) {
  const tags = video.tags || {};
  const rotate = Math.abs(Number(tags.rotate || 0));
  if (Number.isFinite(rotate) && rotate % 360 !== 0) return true;
  const sides = Array.isArray(video.side_data_list) ? video.side_data_list : [];
  return sides.some((s) => {
    const type = String(s.side_data_type || '').toLowerCase();
    if (!type.includes('display matrix') && !type.includes('rotation')) return false;
    const rot = Math.abs(Number(s.rotation || 0));
    return Number.isFinite(rot) && rot % 360 !== 0;
  });
}

async function ffprobeJson(filePath) {
  const { stdout } = await execFileAsync(
    whichBin('ffprobe'),
    [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      filePath,
    ],
    { timeout: 60_000, maxBuffer: 2 * 1024 * 1024 },
  );
  return JSON.parse(stdout);
}

async function runFfmpegNormalize(inputPath, outputPath, { hasAudio }) {
  // H.264 Baseline + AAC + faststart — совместимо с Android MediaCodec (Xiaomi и др.).
  const videoArgs = [
    '-c:v',
    'libx264',
    '-profile:v',
    'baseline',
    '-level',
    '4.0',
    '-pix_fmt',
    'yuv420p',
    // Вписать в 1920 по длинной стороне, чётные размеры, квадратные пиксели.
    // scale применяет поворот из метаданных, затем обнуляем rotate — и телефон, и ПК видят одинаково.
    '-vf',
    "scale='min(1920,iw)':'min(1920,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/16)*16:trunc(ih/16)*16,setsar=1",
    '-metadata:s:v:0',
    'rotate=0',
  ];
  const audioArgs = ['-c:a', 'aac', '-b:a', '128k', '-ac', '2', '-ar', '44100'];
  const tail = ['-movflags', '+faststart', outputPath];

  let args;
  if (hasAudio) {
    args = [
      '-y',
      '-i',
      inputPath,
      '-map',
      '0:v:0',
      '-map',
      '0:a:0',
      ...videoArgs,
      ...audioArgs,
      ...tail,
    ];
  } else {
    // Без звука OEM-плееры иногда падают — добавляем тихий AAC.
    args = [
      '-y',
      '-i',
      inputPath,
      '-f',
      'lavfi',
      '-i',
      'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      ...videoArgs,
      ...audioArgs,
      '-shortest',
      ...tail,
    ];
  }
  await execFileAsync(whichBin('ffmpeg'), args, {
    timeout: FFMPEG_TIMEOUT_MS,
    maxBuffer: 4 * 1024 * 1024,
  });
}

/**
 * Если буфер — видео, которое стоит нормализовать → вернуть mp4 Buffer.
 * При ошибке ffmpeg не подменяем файл исходником: `failed: true`.
 *
 * @returns {Promise<{ buffer: Buffer, mimeType: string, ext: string, normalized: boolean, skipped: boolean, failed?: boolean, reason?: string }>}
 */
async function normalizeVideoBuffer(buffer, { force = false, log = null } = {}) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 32) {
    return {
      buffer,
      mimeType: 'application/octet-stream',
      ext: '.bin',
      normalized: false,
      skipped: true,
      reason: 'empty',
    };
  }

  const id = randomUUID();
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'is-vid-'));
  const inPath = path.join(tmpDir, `in-${id}.bin`);
  const outPath = path.join(tmpDir, `out-${id}.mp4`);

  try {
    await fs.writeFile(inPath, buffer);
    let probe;
    try {
      probe = await ffprobeJson(inPath);
    } catch (e) {
      if (log?.warn) log.warn({ err: e.message }, 'ffprobe failed');
      return {
        buffer,
        mimeType: 'application/octet-stream',
        ext: '.bin',
        normalized: false,
        skipped: false,
        failed: true,
        reason: 'ffprobe_failed',
      };
    }

    const streams = Array.isArray(probe.streams) ? probe.streams : [];
    const hasVideo = streams.some((s) => s.codec_type === 'video');
    const hasAudio = streams.some((s) => s.codec_type === 'audio');
    if (!hasVideo) {
      return {
        buffer,
        mimeType: 'application/octet-stream',
        ext: '.bin',
        normalized: false,
        skipped: true,
        reason: 'not_video',
      };
    }

    if (!force && !needsVideoNormalize(probe)) {
      return {
        buffer,
        mimeType: 'video/mp4',
        ext: '.mp4',
        normalized: false,
        skipped: true,
        reason: 'already_safe',
      };
    }

    await runFfmpegNormalize(inPath, outPath, { hasAudio });
    const out = await fs.readFile(outPath);
    if (!out.length) {
      throw new Error('ffmpeg produced empty file');
    }
    if (log?.info) {
      log.info(
        { inBytes: buffer.length, outBytes: out.length },
        'video normalized to baseline h264+aac',
      );
    }
    return {
      buffer: out,
      mimeType: 'video/mp4',
      ext: '.mp4',
      normalized: true,
      skipped: false,
    };
  } catch (e) {
    if (log?.warn) {
      log.warn({ err: e.message || String(e) }, 'video normalize failed');
    }
    return {
      buffer,
      mimeType: 'video/mp4',
      ext: '.mp4',
      normalized: false,
      skipped: false,
      failed: true,
      reason: 'ffmpeg_failed',
    };
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true }).catch(() => {});
  }
}

module.exports = {
  needsVideoNormalize,
  normalizeVideoBuffer,
  ffprobeJson,
};
