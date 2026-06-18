const { timingSafeEqualString } = require('./security');

function integrationBearerTokenFromRequest(request) {
  const header = request.headers.authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1].trim() : '';
}

function isIntegrationBearerRequest(request) {
  const expected = String(request.server?.config?.integrationBearerToken || '').trim();
  const token = integrationBearerTokenFromRequest(request);
  return Boolean(expected && token && timingSafeEqualString(token, expected));
}

async function verifyIntegrationBearer(request, reply) {
  if (!isIntegrationBearerRequest(request)) {
    return reply.code(401).send({ error: 'INVALID_INTEGRATION_TOKEN' });
  }
}

module.exports = {
  verifyIntegrationBearer,
  isIntegrationBearerRequest,
  integrationBearerTokenFromRequest,
};
