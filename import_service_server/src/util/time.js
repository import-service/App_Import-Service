/** Парсинг значений вида 30d, 12h, 15m в миллисекунды (как в jsonwebtoken). */
function expiresInToMs(expiresIn) {
  if (typeof expiresIn === 'number' && Number.isFinite(expiresIn)) {
    return expiresIn;
  }
  const s = String(expiresIn).trim();
  const m = /^(\d+)(ms|s|m|h|d|w|y)$/i.exec(s);
  if (!m) {
    return 30 * 86400000;
  }
  const n = Number(m[1]);
  const u = m[2].toLowerCase();
  const mult = {
    ms: 1,
    s: 1000,
    m: 60000,
    h: 3600000,
    d: 86400000,
    w: 604800000,
    y: 31557600000,
  };
  return n * (mult[u] || 86400000);
}

function hoursSince(mysqlDate) {
  if (!mysqlDate) return null;
  const t = new Date(mysqlDate).getTime();
  if (Number.isNaN(t)) return null;
  return Math.max(0, Math.floor((Date.now() - t) / 3600000));
}

module.exports = { expiresInToMs, hoursSince };
