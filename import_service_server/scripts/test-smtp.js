require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const nodemailer = require('nodemailer');

const host = process.env.SMTP_HOST;
const port = Number(process.env.SMTP_PORT || 587);
const secure = String(process.env.SMTP_SECURE || 'false').toLowerCase() === 'true';
const user = process.env.SMTP_USER;
const pass = process.env.SMTP_PASS;

const config = {
  host,
  port,
  secure,
  auth: { user, pass },
};

if (String(host || '').includes('gmail.com')) {
  config.requireTLS = true;
  config.secure = false;
  config.tls = { rejectUnauthorized: false };
} else if (String(host || '').includes('yandex')) {
  if (secure || port === 465) {
    config.secure = true;
  } else {
    config.requireTLS = true;
    config.secure = false;
  }
}

const transporter = nodemailer.createTransport(config);

const sendTest = process.argv.includes('--send');

transporter
  .verify()
  .then(async () => {
    console.log('SMTP_OK');
    if (!sendTest) {
      process.exit(0);
      return;
    }
    const to = process.env.MAIL_TO || user;
    const info = await transporter.sendMail({
      from: `"${process.env.APP_NAME || 'Импорт Сервис'}" <${process.env.EMAIL_FROM || user}>`,
      to,
      subject: 'Тест SMTP Import Service',
      text: `Проверка отправки с ${user} на ${to}`,
    });
    console.log('SENT_OK', info.messageId);
    process.exit(0);
  })
  .catch((err) => {
    console.error('SMTP_FAIL', err.code, err.message);
    process.exit(1);
  });
