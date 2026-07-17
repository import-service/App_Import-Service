const { isIntegrationBearerRequest } = require('./integrationAuth');

function mpOrganizationId(request) {
  const id = Number(request.user?.sub);
  if (!Number.isFinite(id) || id <= 0) {
    return null;
  }
  return id;
}

function isMpJwtRequest(request) {
  return !isIntegrationBearerRequest(request);
}

function rowOwnedByOrganization(row, orgId) {
  if (!row || orgId == null) {
    return false;
  }
  return Number(row.organization_id) === orgId;
}

/** Для МП: 404, если заявка не принадлежит организации. Для 1С — пропуск. */
function denyUnlessOwnsRequest(request, reply, row) {
  if (!isMpJwtRequest(request)) {
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
  mpOrganizationId,
  isMpJwtRequest,
  rowOwnedByOrganization,
  denyUnlessOwnsRequest,
};
