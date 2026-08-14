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

function authenticateUserOrIntegrationBearer(fastify) {
  return async function authenticateUserOrIntegration(request, reply) {
    const header = request.headers.authorization || '';
    const match = /^Bearer\s+(.+)$/i.exec(header);
    const token = match ? match[1].trim() : '';
    const expected = String(fastify.config.integrationBearerToken || '').trim();
    if (expected && token && timingSafeEqualString(token, expected)) {
      return;
    }
    try {
      const decoded = await request.jwtVerify();
      if (decoded?.aud === 'admin') {
        await fastify.authenticateAdmin(request, reply);
        return;
      }
    } catch {
      // fall through to authenticate (user JWT)
    }
    await fastify.authenticate(request, reply);
  };
}

module.exports = {
  verifyIntegrationBearer,
  isIntegrationBearerRequest,
  integrationBearerTokenFromRequest,
  authenticateUserOrIntegrationBearer,
};
