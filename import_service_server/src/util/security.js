const crypto = require('crypto');

/** Сравнение секретов: оба значения хешируются, сравнение фиксированной длины. */
function timingSafeEqualString(a, b) {
  const ha = crypto.createHash('sha256').update(String(a), 'utf8').digest();
  const hb = crypto.createHash('sha256').update(String(b), 'utf8').digest();
  return crypto.timingSafeEqual(ha, hb);
}

module.exports = { timingSafeEqualString };
