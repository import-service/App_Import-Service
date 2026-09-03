const { notifyAppFeedback } = require('../services/emailNotification');
const { mpOrganizationId } = require('../util/requestOrganizationAccess');

const FEEDBACK_MESSAGE_MIN = 15;
const FEEDBACK_MESSAGE_MAX = 4000;

function normalize(value) {
  return String(value ?? '').trim();
}

module.exports = async function feedbackRoutes(fastify) {
  fastify.post(
    '/feedback',
    {
      onRequest: [fastify.authenticate],
      schema: {
        body: {
          type: 'object',
          required: ['message'],
          additionalProperties: false,
          properties: {
            message: { type: 'string', minLength: FEEDBACK_MESSAGE_MIN, maxLength: FEEDBACK_MESSAGE_MAX },
            appVersion: { type: 'string', maxLength: 64 },
            platform: { type: 'string', maxLength: 32 },
          },
        },
      },
    },
    async (request, reply) => {
      const orgId = mpOrganizationId(request);
      if (!orgId) {
        return reply.code(401).send({ error: 'UNAUTHORIZED' });
      }

      const message = normalize(request.body.message);
      if (message.length < FEEDBACK_MESSAGE_MIN) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: `Текст не короче ${FEEDBACK_MESSAGE_MIN} символов`,
        });
      }
      if (message.length > FEEDBACK_MESSAGE_MAX) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: `Текст не длиннее ${FEEDBACK_MESSAGE_MAX} символов`,
        });
      }

      const [orgRows] = await fastify.pool.query(
        `SELECT id, id_1c, login, role, org_type, company_name, inn, phone
         FROM organizations
         WHERE id = ? AND deleted_at IS NULL
         LIMIT 1`,
        [orgId],
      );
      if (!orgRows.length) {
        return reply.code(401).send({ error: 'USER_NOT_FOUND' });
      }
      const org = orgRows[0];

      let lastRequest = null;
      try {
        const [reqRows] = await fastify.pool.query(
          `SELECT legal_entity_name, legal_email, legal_phone, legal_inn,
                  individual_full_name, individual_phone, individual_snils
           FROM customs_requests
           WHERE organization_id = ? AND deleted_at IS NULL
           ORDER BY id DESC
           LIMIT 1`,
          [orgId],
        );
        lastRequest = reqRows[0] || null;
      } catch (err) {
        fastify.log.warn({ err, orgId }, 'feedback: last request lookup failed');
      }

      const result = await notifyAppFeedback(
        fastify.config.smtp,
        {
          message,
          organizationId: org.id,
          id1c: org.id_1c,
          login: org.login,
          role: org.role,
          orgType: org.org_type,
          companyName: org.company_name,
          inn: org.inn,
          phone: org.phone,
          legalEntityName: lastRequest?.legal_entity_name,
          legalEmail: lastRequest?.legal_email,
          legalPhone: lastRequest?.legal_phone,
          legalInn: lastRequest?.legal_inn,
          individualFullName: lastRequest?.individual_full_name,
          individualPhone: lastRequest?.individual_phone,
          individualSnils: lastRequest?.individual_snils,
          appVersion: normalize(request.body.appVersion) || null,
          platform: normalize(request.body.platform) || null,
        },
        fastify.log,
      );

      if (!result?.success) {
        fastify.log.error({ err: result?.error, orgId }, 'app feedback email failed');
        return reply.code(502).send({
          error: 'EMAIL_SEND_FAILED',
          message: 'Не удалось отправить обратную связь. Попробуйте позже.',
        });
      }

      return reply.send({ ok: true });
    },
  );
};
