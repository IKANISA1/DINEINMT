const fs = require('fs');
const path = require('path');

const country = process.argv[2];

const configByCountry = {
  rw: {
    envPath: path.resolve(__dirname, '../../dinein_app/env/release.rw.json'),
    functionBase: 'https://kczghhipbyykluuiiunp.supabase.co/functions/v1/whatsapp-otp',
    phone: '+250788767816',
    outputPath: path.resolve(__dirname, '../playwright/rw-fixed-v2-session.json'),
  },
  mt: {
    envPath: path.resolve(__dirname, '../../dinein_app/env/release.mt.json'),
    functionBase: 'https://uskfnszcdqpcfrhjxitl.supabase.co/functions/v1/whatsapp-otp',
    phone: '+356771861993',
    outputPath: path.resolve(__dirname, '../playwright/mt-fixed-v2-session.json'),
  },
};

async function main() {
  const config = configByCountry[country];
  if (!config) {
    throw new Error('Usage: node fetch_admin_session.js <rw|mt>');
  }

  const env = JSON.parse(fs.readFileSync(config.envPath, 'utf8'));
  const anon = env.SUPABASE_ANON_KEY;

  const sendRes = await fetch(config.functionBase, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      apikey: anon,
      authorization: `Bearer ${anon}`,
    },
    body: JSON.stringify({
      action: 'send',
      appScope: 'admin',
      phone: config.phone,
    }),
  });
  const sendJson = await sendRes.json();
  if (!sendRes.ok || !sendJson.success) {
    throw new Error(`send failed: ${JSON.stringify(sendJson)}`);
  }

  const verifyRes = await fetch(config.functionBase, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      apikey: anon,
      authorization: `Bearer ${anon}`,
    },
    body: JSON.stringify({
      action: 'verify',
      appScope: 'admin',
      phone: config.phone,
      verificationId: sendJson.verificationId,
      code: '123456',
    }),
  });
  const verifyJson = await verifyRes.json();
  if (!verifyRes.ok || !verifyJson.success || !verifyJson.verified || !verifyJson.adminSession) {
    throw new Error(`verify failed: ${JSON.stringify(verifyJson)}`);
  }

  fs.writeFileSync(config.outputPath, JSON.stringify(verifyJson.adminSession, null, 2));
  console.log(JSON.stringify({
    country,
    verificationId: sendJson.verificationId,
    verifiedAt: verifyJson.verifiedAt,
    outputPath: config.outputPath,
  }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
