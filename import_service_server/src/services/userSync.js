const bcrypt = require('bcrypt');

const BCRYPT_ROUNDS = 12;

/**
 * Полная синхронизация пользователей из 1С: upsert по external_1c_id, мягкое удаление отсутствующих.
 * @param {import('mysql2/promise').Pool} pool
 * @param {Array<{ external_1c_id: string, login: string, password: string, role: 'admin' | 'user' }>} users
 */
async function syncUsersFrom1C(pool, users) {
  if (!users.length) {
    const err = new Error('Пустой снимок пользователей не принимается');
    err.code = 'EMPTY_SNAPSHOT';
    throw err;
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const externalIds = [...new Set(users.map((u) => u.external_1c_id))];
    const inList = externalIds.map(() => '?').join(',');

    const [toDeactivate] = await conn.query(
      `SELECT id FROM users WHERE deleted_at IS NULL AND external_1c_id NOT IN (${inList})`,
      externalIds,
    );
    const deactivateIds = toDeactivate.map((r) => r.id);

    for (const u of users) {
      const passwordHash = await bcrypt.hash(u.password, BCRYPT_ROUNDS);
      await conn.query(
        `INSERT INTO users (external_1c_id, login, role, password_hash, deleted_at)
         VALUES (?, ?, ?, ?, NULL)
         ON DUPLICATE KEY UPDATE
           login = VALUES(login),
           role = VALUES(role),
           password_hash = VALUES(password_hash),
           deleted_at = NULL,
           updated_at = CURRENT_TIMESTAMP(3)`,
        [u.external_1c_id, u.login, u.role, passwordHash],
      );
    }

    await conn.query(
      `UPDATE users SET deleted_at = CURRENT_TIMESTAMP(3)
       WHERE deleted_at IS NULL AND external_1c_id NOT IN (${inList})`,
      externalIds,
    );

    if (deactivateIds.length) {
      const ph = deactivateIds.map(() => '?').join(',');
      await conn.query(
        `UPDATE user_sessions SET revoked_at = CURRENT_TIMESTAMP(3)
         WHERE revoked_at IS NULL AND user_id IN (${ph})`,
        deactivateIds,
      );
    }

    await conn.commit();

    return {
      upsertedRows: users.length,
      uniqueExternalIds: externalIds.length,
      softDeletedUsers: deactivateIds.length,
    };
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

module.exports = { syncUsersFrom1C };
