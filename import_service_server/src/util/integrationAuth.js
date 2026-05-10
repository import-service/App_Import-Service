const { timingSafeEqualString } = require('./security');

async function verifyIntegrationBearer(request, reply) {
  const expected = request.server.config.integrationBearerToken;
  const header = request.headers.authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  const token = match ? match[1].trim() : '';
  if (!timingSafeEqualString(token, expected)) {
    return reply.code(401).send({ error: 'INVALID_INTEGRATION_TOKEN' });
  }
}

module.exports = { verifyIntegrationBearer };
