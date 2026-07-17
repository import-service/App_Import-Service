require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const nodemailer = require('nodemailer');

const recipients = process.argv.slice(2);
const targets =
  recipients.length > 0
    ? recipients
    : [
        'info@import-service.ru',
        'info@import-service.su',
        'admin@import-service.su',
        'nykolayr@gmail.com',
      ];

const port = Number(process.env.SMTP_PORT || 465);
const secure = String(process.env.SMTP_SECURE || 'true').toLowerCase() === 'true';
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port,
  secure,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function main() {
  await transporter.verify();
  console.log('SMTP_OK', process.env.SMTP_USER);
  for (const to of targets) {
    try {
      const info = await transporter.sendMail({
        from: `"${process.env.APP_NAME || 'Импорт Сервис'}" <${process.env.EMAIL_FROM || process.env.SMTP_USER}>`,
        to,
        subject: `diag delivery ${to}`,
        text: `Test from ${process.env.SMTP_USER} to ${to}`,
      });
      console.log('QUEUED_OK', to, info.messageId);
    } catch (err) {
      console.log('QUEUE_FAIL', to, err.code || '', err.message);
    }
  }
}

main().catch((err) => {
  console.error('FATAL', err.message);
  process.exit(1);
});
