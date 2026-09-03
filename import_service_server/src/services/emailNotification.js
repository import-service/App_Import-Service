const nodemailer = require('nodemailer');

const NEW_CUSTOMS_REQUEST_SUBJECT = 'Новая заявка приложение Импорт Сервис';
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

function formatImportDates(body) {
  const dates = Array.isArray(body.previousImportDates) ? body.previousImportDates : [];
  if (!dates.length) return formatYesNo(Boolean(body.importedLast12Months));
  return dates.map((d) => String(d)).join(', ');
}

function formatOwnedVehicles(body) {
  const cars = Array.isArray(body.ownedVehicles) ? body.ownedVehicles : [];
  if (!cars.length) return formatYesNo(Boolean(body.ownsOtherCars));
  return cars
    .map((c) => {
      const name = String(c?.name ?? '').trim();
      const year = c?.year != null ? String(c.year) : '';
      return [name, year].filter(Boolean).join(', ');
    })
    .filter(Boolean)
    .join('; ');
}

function normalize(value) {
  return String(value ?? '').trim();
}

/**
 * @param {import('../config')} smtpConfig — fastify.config.smtp
 * @returns {Promise<{ success: boolean, messageId?: string, error?: string }>}
 */
async function sendPlainEmail(smtpConfig, { to, subject, html, text, replyTo = null, attachments = null }, log) {
  const recipients = (Array.isArray(to) ? to : [to])
    .map((x) => normalize(x))
    .filter(Boolean);
  const subjectNorm = normalize(subject) || smtpConfig.appName || 'Импорт Сервис';
  const replyToNorm = replyTo ? normalize(replyTo) : null;
  const fromHeader = resolveFromHeader(smtpConfig);
  if (!recipients.length) {
    if (log?.warn) {
      log.warn(
        { subject: subjectNorm, from: fromHeader },
        '[email] skip: No recipients',
      );
    }
    return { success: false, error: 'No recipients' };
  }

  try {
    const transporter = getTransporter(smtpConfig);
    const mail = {
      from: fromHeader,
      to: recipients.join(', '),
      replyTo: replyToNorm || undefined,
      subject: subjectNorm,
      html,
      text,
    };
    if (Array.isArray(attachments) && attachments.length) {
      mail.attachments = attachments;
    }
    const info = await transporter.sendMail(mail);
    if (log?.info) {
      log.info(
        {
          to: recipients,
          replyTo: replyToNorm,
          subject: subjectNorm,
          from: fromHeader,
          messageId: info.messageId || null,
          accepted: info.accepted || null,
          rejected: info.rejected || null,
        },
        '[email] sent',
      );
    }
    return { success: true, messageId: info.messageId };
  } catch (err) {
    if (log?.error) {
      log.error(
        {
          err,
          code: err.code,
          responseCode: err.responseCode,
          to: recipients,
          replyTo: replyToNorm,
          subject: subjectNorm,
          from: fromHeader,
        },
        '[email] sendPlainEmail failed',
      );
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
    `  Ввоз за 12 мес.: ${formatImportDates(body)}`,
    `  Другие авто в собственности: ${formatOwnedVehicles(body)}`,
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
    <p><b>Ввоз за 12 мес.:</b> ${escapeHtml(formatImportDates(body))}</p>
    <p><b>Другие авто в собственности:</b> ${escapeHtml(formatOwnedVehicles(body))}</p>
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

const CLIENT_RATING_SUBJECT = 'Оценка клиента в приложении Импорт Сервис';

/** Письмо руководству: клиент поставил оценку заявке. */
async function notifyClientRequestRating(
  smtpConfig,
  {
    requestId,
    rating,
    comment,
    vin,
    carMake,
    carModel,
    legalEntityName,
    organizationLogin,
  },
  log,
) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const to = normalize(smtpConfig.customsRequestMailTo) || normalize(smtpConfig.to);
  if (!to) {
    return { success: false, error: 'No rating recipients' };
  }
  const stars = '★'.repeat(Number(rating) || 0) + '☆'.repeat(Math.max(0, 5 - (Number(rating) || 0)));
  const carLine = [normalize(carMake), normalize(carModel)].filter(Boolean).join(' ') || '—';
  const commentLine = normalize(comment) || '—';
  const orgLine = normalize(legalEntityName) || normalize(organizationLogin) || '—';

  const text = [
    `Оценка клиента в приложении «${appName}»`,
    '',
    `Заявка: #${requestId}`,
    `Оценка: ${rating} / 5 (${stars})`,
    `Авто: ${carLine}`,
    `VIN: ${normalize(vin) || '—'}`,
    `Организация: ${orgLine}`,
    `Комментарий: ${commentLine}`,
  ].join('\n');

  const html = `
    <h2>Оценка клиента — ${escapeHtml(appName)}</h2>
    <table cellpadding="6" cellspacing="0" border="0">
      <tr><td><b>Заявка</b></td><td>#${escapeHtml(String(requestId))}</td></tr>
      <tr><td><b>Оценка</b></td><td>${escapeHtml(String(rating))} / 5 &nbsp; ${escapeHtml(stars)}</td></tr>
      <tr><td><b>Авто</b></td><td>${escapeHtml(carLine)}</td></tr>
      <tr><td><b>VIN</b></td><td>${escapeHtml(normalize(vin) || '—')}</td></tr>
      <tr><td><b>Организация</b></td><td>${escapeHtml(orgLine)}</td></tr>
      <tr><td><b>Комментарий</b></td><td>${escapeHtml(commentLine)}</td></tr>
    </table>
  `;

  return sendPlainEmail(
    smtpConfig,
    {
      to,
      subject: `${CLIENT_RATING_SUBJECT}: ${rating}/5 · #${requestId}`,
      html,
      text,
    },
    log,
  );
}

const APP_FEEDBACK_SUBJECT = 'Обратная связь приложение Импорт Сервис';
const APP_FEEDBACK_MAIL_TO = 'info@import-service.su';

/** Письмо на info@: отзыв / идеи по улучшению из МП (Профиль). */
async function notifyAppFeedback(
  smtpConfig,
  {
    message,
    organizationId,
    id1c,
    login,
    role,
    orgType,
    companyName,
    inn,
    phone,
    legalEntityName,
    legalEmail,
    legalPhone,
    legalInn,
    individualFullName,
    individualPhone,
    individualSnils,
    appVersion,
    platform,
  },
  log,
) {
  const appName = smtpConfig.appName || 'Импорт Сервис';
  const to =
    normalize(APP_FEEDBACK_MAIL_TO) ||
    normalize(smtpConfig.customsRequestMailTo) ||
    normalize(smtpConfig.to);
  if (!to) {
    return { success: false, error: 'No feedback recipients' };
  }

  const dash = (v) => normalize(v) || '—';
  const when = new Date().toISOString();
  const replyTo = normalize(login) || null;

  const text = [
    `Обратная связь из приложения «${appName}»`,
    '',
    `Сообщение:`,
    normalize(message),
    '',
    `— Учётка —`,
    `ID организации: ${dash(organizationId)}`,
    `ID 1С: ${dash(id1c)}`,
    `Логин (email): ${dash(login)}`,
    `Роль: ${dash(role)}`,
    `Тип: ${dash(orgType)}`,
    `Наименование: ${dash(companyName)}`,
    `ИНН (учётка): ${dash(inn)}`,
    `Телефон (учётка): ${dash(phone)}`,
    '',
    `— Из последней заявки (если есть) —`,
    `ЮЛ/ИП: ${dash(legalEntityName)}`,
    `Email ЮЛ: ${dash(legalEmail)}`,
    `Телефон ЮЛ: ${dash(legalPhone)}`,
    `ИНН ЮЛ: ${dash(legalInn)}`,
    `ФИО физлица: ${dash(individualFullName)}`,
    `Телефон физлица: ${dash(individualPhone)}`,
    `СНИЛС: ${dash(individualSnils)}`,
    '',
    `— Клиент —`,
    `Версия МП: ${dash(appVersion)}`,
    `Платформа: ${dash(platform)}`,
    `Отправлено: ${when}`,
  ].join('\n');

  const html = `
    <h2>Обратная связь — ${escapeHtml(appName)}</h2>
    <p style="white-space:pre-wrap">${escapeHtml(normalize(message))}</p>
    <h3>Учётка</h3>
    <table cellpadding="6" cellspacing="0" border="0">
      <tr><td><b>ID организации</b></td><td>${escapeHtml(dash(organizationId))}</td></tr>
      <tr><td><b>ID 1С</b></td><td>${escapeHtml(dash(id1c))}</td></tr>
      <tr><td><b>Логин (email)</b></td><td>${escapeHtml(dash(login))}</td></tr>
      <tr><td><b>Роль</b></td><td>${escapeHtml(dash(role))}</td></tr>
      <tr><td><b>Тип</b></td><td>${escapeHtml(dash(orgType))}</td></tr>
      <tr><td><b>Наименование</b></td><td>${escapeHtml(dash(companyName))}</td></tr>
      <tr><td><b>ИНН (учётка)</b></td><td>${escapeHtml(dash(inn))}</td></tr>
      <tr><td><b>Телефон (учётка)</b></td><td>${escapeHtml(dash(phone))}</td></tr>
    </table>
    <h3>Из последней заявки (если есть)</h3>
    <table cellpadding="6" cellspacing="0" border="0">
      <tr><td><b>ЮЛ/ИП</b></td><td>${escapeHtml(dash(legalEntityName))}</td></tr>
      <tr><td><b>Email ЮЛ</b></td><td>${escapeHtml(dash(legalEmail))}</td></tr>
      <tr><td><b>Телефон ЮЛ</b></td><td>${escapeHtml(dash(legalPhone))}</td></tr>
      <tr><td><b>ИНН ЮЛ</b></td><td>${escapeHtml(dash(legalInn))}</td></tr>
      <tr><td><b>ФИО физлица</b></td><td>${escapeHtml(dash(individualFullName))}</td></tr>
      <tr><td><b>Телефон физлица</b></td><td>${escapeHtml(dash(individualPhone))}</td></tr>
      <tr><td><b>СНИЛС</b></td><td>${escapeHtml(dash(individualSnils))}</td></tr>
    </table>
    <h3>Клиент</h3>
    <table cellpadding="6" cellspacing="0" border="0">
      <tr><td><b>Версия МП</b></td><td>${escapeHtml(dash(appVersion))}</td></tr>
      <tr><td><b>Платформа</b></td><td>${escapeHtml(dash(platform))}</td></tr>
      <tr><td><b>Отправлено</b></td><td>${escapeHtml(when)}</td></tr>
    </table>
  `;

  return sendPlainEmail(
    smtpConfig,
    {
      to,
      replyTo,
      subject: APP_FEEDBACK_SUBJECT,
      html,
      text,
    },
    log,
  );
}

module.exports = {
  NEW_CUSTOMS_REQUEST_SUBJECT,
  CLIENT_REQUEST_ACCEPTED_SUBJECT,
  CLIENT_RATING_SUBJECT,
  APP_FEEDBACK_SUBJECT,
  sendPlainEmail,
  notifyNewCustomsRequest,
  notifyClientRegistrationAccepted,
  notifyClientCustomsRequestAccepted,
  notifyClientRequestRating,
  notifyAppFeedback,
  escapeHtml,
};
