const nodemailer = require('nodemailer');

const NEW_CUSTOMS_REQUEST_SUBJECT = 'Новый клиент приложение Импорт Сервис';
const CLIENT_REQUEST_ACCEPTED_SUBJECT = 'Заявка принята на рассмотрение';

let cachedTransporter = null;
let cachedTransporterKey = null;

function getTransporter(smtp) {
  const key = `${smtp.host}:${smtp.port}:${smtp.user}:${smtp.secure}`;
  if (cachedTransporter && cachedTransporterKey === key) {
    return cachedTransporter;
  }
  const config = {
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    auth: {
      user: smtp.user,
      pass: smtp.pass,
    },
  };
  if (String(smtp.host || '').includes('gmail.com')) {
    config.requireTLS = true;
    config.secure = false;
    config.tls = { rejectUnauthorized: false };
  } else if (String(smtp.host || '').includes('yandex')) {
    if (smtp.secure || smtp.port === 465) {
      config.secure = true;
    } else {
      config.requireTLS = true;
      config.secure = false;
    }
  }
  cachedTransporter = nodemailer.createTransport(config);
  cachedTransporterKey = key;
  return cachedTransporter;
}

function resolveFromHeader(smtpConfig) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const smtpUser = normalize(smtpConfig.user);
  const configuredFrom = normalize(smtpConfig.from);
  // Gmail: без «Send mail as» отправитель = учётная запись SMTP.
  const fromEmail =
    String(smtpConfig.host || '').includes('gmail.com') && smtpUser
      ? smtpUser
      : configuredFrom || smtpUser;
  return `"${appName}" <${fromEmail}>`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatYesNo(value) {
  return value ? 'Да' : 'Нет';
}

function normalize(value) {
  return String(value ?? '').trim();
}

/**
 * @param {import('../config')} smtpConfig — fastify.config.smtp
 * @returns {Promise<{ success: boolean, messageId?: string, error?: string }>}
 */
async function sendPlainEmail(smtpConfig, { to, subject, html, text, replyTo = null }, log) {
  const recipients = (Array.isArray(to) ? to : [to])
    .map((x) => normalize(x))
    .filter(Boolean);
  if (!recipients.length) {
    return { success: false, error: 'No recipients' };
  }

  try {
    const transporter = getTransporter(smtpConfig);
    const info = await transporter.sendMail({
      from: resolveFromHeader(smtpConfig),
      to: recipients.join(', '),
      replyTo: replyTo || undefined,
      subject: normalize(subject) || smtpConfig.appName || 'Импорт Сервис',
      html,
      text,
    });
    return { success: true, messageId: info.messageId };
  } catch (err) {
    if (log?.error) {
      log.error({ err, code: err.code }, '[email] sendPlainEmail failed');
    }
    return { success: false, error: err.message, code: err.code };
  }
}

function buildNewCustomsRequestEmail({ requestId, body, legalInn, appName }) {
  const submittedAt = new Date().toISOString();
  const commentText = normalize(body.commentText);

  const lines = [
    `Приложение: ${appName}`,
    '',
    'Новая заявка на таможенное оформление.',
    '',
    `ID заявки: ${requestId}`,
    '',
    'Организация / юрлицо:',
    `  Наименование: ${normalize(body.legalEntityName)}`,
    `  ИНН: ${legalInn}`,
    `  Email: ${normalize(body.legalEmail)}`,
    `  Телефон: ${normalize(body.legalPhone)}`,
    '',
    'Физлицо:',
    `  ФИО: ${normalize(body.individualFullName)}`,
    `  Телефон: ${normalize(body.individualPhone)}`,
    `  СНИЛС: ${normalize(body.individualSnils)}`,
    '',
    'Автомобиль:',
    `  Марка: ${normalize(body.carMake)}`,
    `  Модель: ${normalize(body.carModel)}`,
    `  VIN: ${normalize(body.vin)}`,
    '',
    'Дополнительно:',
    `  Люк / панорама: ${formatYesNo(Boolean(body.hasSunroof))}`,
    `  Полный привод: ${formatYesNo(Boolean(body.hasAllWheelDrive))}`,
    `  Ввоз за 12 мес.: ${formatYesNo(Boolean(body.importedLast12Months))}`,
    `  Другие авто в собственности: ${formatYesNo(Boolean(body.ownsOtherCars))}`,
  ];

  if (commentText) {
    lines.push('', 'Комментарий:', commentText);
  }

  lines.push('', `Дата: ${submittedAt}`);

  const text = lines.join('\n');
  const html = `
    <h2>${escapeHtml(NEW_CUSTOMS_REQUEST_SUBJECT)}</h2>
    <p><b>Приложение:</b> ${escapeHtml(appName)}</p>
    <p><b>ID заявки:</b> ${escapeHtml(requestId)}</p>
    <h3>Организация / юрлицо</h3>
    <p><b>Наименование:</b> ${escapeHtml(body.legalEntityName)}</p>
    <p><b>ИНН:</b> ${escapeHtml(legalInn)}</p>
    <p><b>Email:</b> ${escapeHtml(body.legalEmail)}</p>
    <p><b>Телефон:</b> ${escapeHtml(body.legalPhone)}</p>
    <h3>Физлицо</h3>
    <p><b>ФИО:</b> ${escapeHtml(body.individualFullName)}</p>
    <p><b>Телефон:</b> ${escapeHtml(body.individualPhone)}</p>
    <p><b>СНИЛС:</b> ${escapeHtml(body.individualSnils)}</p>
    <h3>Автомобиль</h3>
    <p><b>Марка:</b> ${escapeHtml(body.carMake)}</p>
    <p><b>Модель:</b> ${escapeHtml(body.carModel)}</p>
    <p><b>VIN:</b> ${escapeHtml(body.vin)}</p>
    <h3>Дополнительно</h3>
    <p><b>Люк / панорама:</b> ${formatYesNo(Boolean(body.hasSunroof))}</p>
    <p><b>Полный привод:</b> ${formatYesNo(Boolean(body.hasAllWheelDrive))}</p>
    <p><b>Ввоз за 12 мес.:</b> ${formatYesNo(Boolean(body.importedLast12Months))}</p>
    <p><b>Другие авто в собственности:</b> ${formatYesNo(Boolean(body.ownsOtherCars))}</p>
    ${
      commentText
        ? `<h3>Комментарий</h3><p style="white-space: pre-wrap;">${escapeHtml(commentText)}</p>`
        : ''
    }
    <p><b>Дата:</b> ${escapeHtml(submittedAt)}</p>
  `;

  return {
    subject: NEW_CUSTOMS_REQUEST_SUBJECT,
    text,
    html,
    replyTo: normalize(body.legalEmail) || null,
  };
}

/**
 * Уведомление на почту о новой заявке (подача анкеты).
 * @returns {Promise<{ success: boolean, messageId?: string, error?: string }>}
 */
async function notifyNewCustomsRequest(smtpConfig, { requestId, body, legalInn }, log) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const to = smtpConfig.customsRequestMailTo || smtpConfig.to;
  const mail = buildNewCustomsRequestEmail({ requestId, body, legalInn, appName });
  return sendPlainEmail(
    smtpConfig,
    {
      to,
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
      replyTo: mail.replyTo,
    },
    log,
  );
}

function buildClientAcceptedEmail({ appName, requestId, recipientName }) {
  const greeting = recipientName
    ? `Здравствуйте, ${recipientName}!`
    : 'Здравствуйте!';
  const requestLine = requestId
    ? `Номер заявки: ${requestId}.`
    : 'Мы получили вашу заявку.';

  const text = [
    greeting,
    '',
    `Ваша заявка в приложении «${appName}» принята на рассмотрение.`,
    requestLine,
    '',
    'Мы свяжемся с вами по указанным контактам после проверки данных.',
    '',
    `С уважением,`,
    appName,
  ].join('\n');

  const html = `
    <p>${escapeHtml(greeting)}</p>
    <p>Ваша заявка в приложении <b>${escapeHtml(appName)}</b> принята на рассмотрение.</p>
    <p>${escapeHtml(requestLine)}</p>
    <p>Мы свяжемся с вами по указанным контактам после проверки данных.</p>
    <p>С уважением,<br>${escapeHtml(appName)}</p>
  `;

  return { subject: CLIENT_REQUEST_ACCEPTED_SUBJECT, text, html };
}

/** Подтверждение клиенту: заявка на регистрацию (логин в приложение). */
async function notifyClientRegistrationAccepted(
  smtpConfig,
  { email, displayName },
  log,
) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const clientEmail = normalize(email);
  if (!clientEmail) {
    return { success: false, error: 'No client email' };
  }
  const mail = buildClientAcceptedEmail({
    appName,
    requestId: null,
    recipientName: normalize(displayName) || null,
  });
  return sendPlainEmail(
    smtpConfig,
    {
      to: clientEmail,
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
    },
    log,
  );
}

/** Подтверждение клиенту: заявка на таможенное оформление. */
async function notifyClientCustomsRequestAccepted(
  smtpConfig,
  { requestId, legalEmail, legalEntityName },
  log,
) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const clientEmail = normalize(legalEmail);
  if (!clientEmail) {
    return { success: false, error: 'No client email' };
  }
  const mail = buildClientAcceptedEmail({
    appName,
    requestId,
    recipientName: normalize(legalEntityName) || null,
  });
  return sendPlainEmail(
    smtpConfig,
    {
      to: clientEmail,
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
    },
    log,
  );
}

module.exports = {
  NEW_CUSTOMS_REQUEST_SUBJECT,
  CLIENT_REQUEST_ACCEPTED_SUBJECT,
  sendPlainEmail,
  notifyNewCustomsRequest,
  notifyClientRegistrationAccepted,
  notifyClientCustomsRequestAccepted,
  escapeHtml,
};
