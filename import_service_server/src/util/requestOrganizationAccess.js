const { isIntegrationBearerRequest } = require('./integrationAuth');

const ROLE_SVH_MANAGER = 'svh_manager';

function mpOrganizationId(request) {
  const id = Number(request.user?.sub);
  if (!Number.isFinite(id) || id <= 0) {
    return null;
  }
  return id;
}

function mpUserRole(request) {
  return String(request.user?.role || '').trim();
}

function isSvhManagerRequest(request) {
  return isMpJwtRequest(request) && mpUserRole(request) === ROLE_SVH_MANAGER;
}

function isMpJwtRequest(request) {
  if (isIntegrationBearerRequest(request)) {
    return false;
  }
  // JWT админки (aud: admin) — не ограничивать по organization_id МП
  if (request.user?.aud === 'admin') {
    return false;
  }
  return Boolean(request.user?.sub);
}

function rowOwnedByOrganization(row, orgId) {
  if (!row || orgId == null) {
    return false;
  }
  return Number(row.organization_id) === orgId;
}

/** Для МП: 404, если заявка не принадлежит организации. СВХ-менеджер — доступ ко всем. Для 1С — пропуск. */
function denyUnlessOwnsRequest(request, reply, row) {
  if (!isMpJwtRequest(request)) {
    return true;
  }
  if (isSvhManagerRequest(request)) {
    return true;
  }
  const orgId = mpOrganizationId(request);
  if (!rowOwnedByOrganization(row, orgId)) {
    reply.code(404).send({ error: 'NOT_FOUND' });
    return false;
  }
  return true;
}

module.exports = {
  ROLE_SVH_MANAGER,
  mpOrganizationId,
  mpUserRole,
  isSvhManagerRequest,
  isMpJwtRequest,
  rowOwnedByOrganization,
  denyUnlessOwnsRequest,
};
