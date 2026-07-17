const { sendPlainEmail, notifyClientRegistrationAccepted } = require('../services/emailNotification');

const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 5;

function normalize(v) {
  return String(v || '').trim();
}

module.exports = async function registrationRoutes(fastify) {
  const requestBuckets = new Map();

  fastify.post(
    '/registration-request',
    {
      schema: {
        body: {
          type: 'object',
          required: ['orgType', 'inn', 'phone', 'email'],
          properties: {
            orgType: { type: 'string', enum: ['OOO', 'IP'] },
            companyName: { type: 'string', minLength: 2, maxLength: 255 },
            fullName: { type: 'string', minLength: 3, maxLength: 255 },
            inn: { type: 'string', minLength: 10, maxLength: 12 },
            phone: { type: 'string', minLength: 5, maxLength: 30 },
            email: { type: 'string', format: 'email', maxLength: 255 },
          },
        },
      },
    },
    async (request, reply) => {
      const ip = request.ip || request.headers['x-real-ip'] || 'unknown';
      const now = Date.now();
      const current = requestBuckets.get(ip) || [];
      const fresh = current.filter((ts) => now - ts < RATE_LIMIT_WINDOW_MS);
      if (fresh.length >= RATE_LIMIT_MAX_REQUESTS) {
        return reply.code(429).send({
          error: 'TOO_MANY_REQUESTS',
          message: 'Слишком много заявок, попробуйте позже',
        });
      }
      fresh.push(now);
      requestBuckets.set(ip, fresh);

      const orgType = normalize(request.body.orgType).toUpperCase();
      const companyName = normalize(request.body.companyName);
      const fullName = normalize(request.body.fullName);
      const inn = normalize(request.body.inn);
      const phone = normalize(request.body.phone);
      const email = normalize(request.body.email);

      if (orgType !== 'OOO' && orgType !== 'IP') {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'orgType должен быть OOO или IP',
        });
      }

      if (orgType === 'OOO' && !companyName) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Для OOO обязательно поле companyName',
        });
      }

      if (orgType === 'IP' && !fullName) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'Для IP обязательно поле fullName (ФИО)',
        });
      }

      if (!/^\d{10}(\d{2})?$/.test(inn)) {
        return reply.code(400).send({
          error: 'VALIDATION_ERROR',
          message: 'ИНН должен содержать 10 или 12 цифр',
        });
      }

      const subject = 'Заявка регистрация приложение';
      const title = orgType === 'OOO' ? 'ООО' : 'ИП';
      const orgLabel = orgType === 'OOO' ? `Компания: ${companyName}` : `ФИО ИП: ${fullName}`;
      const text = [
        `Приложение: ${fastify.config.smtp.appName}`,
        '',
        'Новая заявка на получение данных для входа.',
        '',
        `Тип организации: ${title}`,
        orgLabel,
        `ИНН: ${inn}`,
        `Телефон: ${phone}`,
        `Email: ${email}`,
        '',
        `Дата: ${new Date().toISOString()}`,
      ].join('\n');

      const html = `
        <h2>Заявка регистрация приложение</h2>
        <p><b>Приложение:</b> ${fastify.config.smtp.appName}</p>
        <p><b>Тип организации:</b> ${title}</p>
        <p><b>${orgType === 'OOO' ? 'Компания' : 'ФИО ИП'}:</b> ${
          orgType === 'OOO' ? companyName : fullName
        }</p>
        <p><b>ИНН:</b> ${inn}</p>
        <p><b>Телефон:</b> ${phone}</p>
        <p><b>Email:</b> ${email}</p>
        <p><b>Дата:</b> ${new Date().toISOString()}</p>
      `;

      const result = await sendPlainEmail(
        fastify.config.smtp,
        {
          to: fastify.config.smtp.to,
          subject,
          text,
          html,
          replyTo: email,
        },
        fastify.log,
      );

      if (!result.success) {
        fastify.log.error(
          { code: result.code, smtpUser: fastify.config.smtp.user },
          'registration email failed',
        );
        return reply.code(500).send({
          error: 'EMAIL_SEND_FAILED',
          message: 'Не удалось отправить заявку, попробуйте позже',
        });
      }

      const displayName = orgType === 'OOO' ? companyName : fullName;
      notifyClientRegistrationAccepted(
        fastify.config.smtp,
        { email, displayName },
        fastify.log,
      ).catch((err) => {
        fastify.log.error({ err, email }, 'registration client confirmation email failed');
      });

      return reply.send({ ok: true, message: 'Заявка отправлена' });
    },
  );
};
