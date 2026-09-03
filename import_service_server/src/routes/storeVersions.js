const {
  runStoreVersionScan,
  getStoreVersionsDto,
} = require('../services/storeVersionScanner');

module.exports = async function storeVersionRoutes(fastify) {
  fastify.get('/app/store-versions', async (_request, reply) => {
    try {
      const dto = await getStoreVersionsDto(fastify.pool);
      return reply.send(dto);
    } catch (e) {
      if (e && e.code === 'ER_NO_SUCH_TABLE') {
        return reply.code(503).send({ error: 'STORE_VERSION_STORAGE_NOT_READY' });
      }
      throw e;
    }
  });

  fastify.get(
    '/admin/store-versions',
    { onRequest: [fastify.authenticateAdmin] },
    async (_request, reply) => {
      try {
        const dto = await getStoreVersionsDto(fastify.pool);
        return reply.send(dto);
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'STORE_VERSION_STORAGE_NOT_READY' });
        }
        throw e;
      }
    },
  );

  fastify.post(
    '/admin/store-versions/scan',
    { onRequest: [fastify.authenticateAdmin] },
    async (_request, reply) => {
      try {
        const result = await runStoreVersionScan(fastify);
        const dto = await getStoreVersionsDto(fastify.pool);
        return reply.send({ ...result, ...dto });
      } catch (e) {
        if (e && e.code === 'ER_NO_SUCH_TABLE') {
          return reply.code(503).send({ error: 'STORE_VERSION_STORAGE_NOT_READY' });
        }
        fastify.log.error({ err: e.message }, 'manual store version scan failed');
        return reply.code(500).send({
          error: 'STORE_VERSION_SCAN_FAILED',
          message: e.message,
        });
      }
    },
  );
};
