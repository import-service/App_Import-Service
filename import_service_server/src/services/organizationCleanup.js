/**
 * Мягкое удаление организации и связанных данных.
 * Общая логика для админки (DELETE /admin/organizations/:id)
 * и интеграции 1С (POST /integration/organizations/delete).
 *
 * Каскад: заявки по legal_email, активные сессии, push-токены.
 * Файлы на диске не трогаем — заявки помечаются deleted_at, файлы доступны по прямой ссылке.
 */
async function softDeleteOrganizationCascade(pool, orgId, login) {
  await pool.query(
    `UPDATE organizations
     SET deleted_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3)
     WHERE id = ?`,
    [orgId],
  );
  const [reqResult] = await pool.query(
    `UPDATE customs_requests
     SET deleted_at = CURRENT_TIMESTAMP(3)
     WHERE legal_email = ? AND deleted_at IS NULL`,
    [login],
  );
  await pool.query(
    `UPDATE user_sessions
     SET revoked_at = CURRENT_TIMESTAMP(3)
     WHERE user_id = ? AND revoked_at IS NULL`,
    [orgId],
  );
  await pool.query(
    `UPDATE user_push_tokens
     SET deleted_at = CURRENT_TIMESTAMP(3)
     WHERE org_id = ? AND deleted_at IS NULL`,
    [orgId],
  );
  return { deletedRequests: reqResult.affectedRows || 0 };
}

/**
 * Восстановление мягко удалённой организации и её заявок.
 * Сессии и push-токены не воскрешаются — пользователь войдёт заново.
 */
async function restoreOrganizationCascade(pool, orgId, login) {
  await pool.query(
    `UPDATE organizations
     SET deleted_at = NULL, updated_at = CURRENT_TIMESTAMP(3)
     WHERE id = ?`,
    [orgId],
  );
  const [reqResult] = await pool.query(
    `UPDATE customs_requests
     SET deleted_at = NULL
     WHERE legal_email = ? AND deleted_at IS NOT NULL`,
    [login],
  );
  return { restoredRequests: reqResult.affectedRows || 0 };
}

module.exports = { softDeleteOrganizationCascade, restoreOrganizationCascade };
