require('dotenv').config();
const path = require('path');

function required(name) {
  const v = process.env[name];
  if (v === undefined || v === '') {
    throw new Error(`Отсутствует обязательная переменная окружения: ${name}`);
  }
  return v;
}

const SERVER_ROOT = path.join(__dirname, '..');

function resolveAdminWebRoot() {
  const raw = String(process.env.ADMIN_WEB_ROOT || 'web').trim() || 'web';
  if (path.isAbsolute(raw)) {
    return raw;
  }
  return path.join(SERVER_ROOT, raw);
}

/** Разрешённые Origin для CORS (локальная веб-админка: flutter run -d chrome). */
function parseCorsOrigins() {
  const raw = String(process.env.CORS_ORIGINS || '').trim();
  if (raw === '*') return '*';
  if (raw) {
    return raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return null;
}

function isLocalDevOrigin(origin) {
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
}

module.exports = {
  SERVER_ROOT,
  corsOrigins: parseCorsOrigins(),
  isLocalDevOrigin,
  /** Каталог Flutter Web (содержимое build/web) для GET /admin/ */
  adminWebRoot: resolveAdminWebRoot(),
  /** База для абсолютных URL в API (fileUrl, vehiclePhotoUrls). Пример: https://example.com */
  publicBaseUrl: String(process.env.PUBLIC_BASE_URL || '')
    .trim()
    .replace(/\/$/, ''),
  port: Number(process.env.PORT || 3000),
  mysql: {
    host: process.env.MYSQL_HOST || '127.0.0.1',
    port: Number(process.env.MYSQL_PORT || 3306),
    user: required('MYSQL_USER'),
    password: required('MYSQL_PASSWORD'),
    database: required('MYSQL_DATABASE'),
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
  },
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',
  integrationBearerToken: required('INTEGRATION_BEARER_TOKEN'),
  chat: {
    // Realtime: отдельный порт (ws+broadcast) — проксируйте /ws/ с nginx на этот порт, если нужен wss
    broadcastPort: Number(process.env.CHAT_BROADCAST_PORT || 3010),
    broadcastSecret: required('CHAT_BROADCAST_SECRET'),
  },
  smtp: {
    host: required('SMTP_HOST'),
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false').toLowerCase() === 'true',
    user: required('SMTP_USER'),
    pass: required('SMTP_PASS'),
    from: required('EMAIL_FROM'),
    to: required('MAIL_TO'),
    /** Почта при подаче заявки (POST /customs-requests). */
    customsRequestMailTo: String(
      process.env.CUSTOMS_REQUEST_MAIL_TO || 'info@import-service.ru',
    ).trim(),
    appName: process.env.APP_NAME || 'Импорт Сервис',
  },
  push: {
    fcm: {
      projectId: String(process.env.FCM_PROJECT_ID || '').trim(),
      clientEmail: String(process.env.FCM_CLIENT_EMAIL || '').trim(),
      privateKey: String(process.env.FCM_PRIVATE_KEY || '')
        .replace(/\\n/g, '\n')
        .trim(),
    },
  },
  demoFlow: {
    enabled: String(process.env.DEMO_FLOW_ENABLED || 'true').toLowerCase() === 'true',
    stepMs: Number(process.env.DEMO_FLOW_STEP_MS || 180000),
    /** Быстрые шаги для ФИО «Тестов Тест Тестович» (по умолчанию 60 с). */
    fastStepMs: Number(process.env.DEMO_FLOW_FAST_STEP_MS || 60000),
    chatReplyMs: Number(process.env.DEMO_FLOW_CHAT_REPLY_MS || 4000),
  },
};
