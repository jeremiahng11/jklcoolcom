import admin from 'firebase-admin';
import { store } from './store.js';

export function initFcm(): void {
  if (admin.apps.length) return;
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (b64) {
    const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
    admin.initializeApp({ credential: admin.credential.cert(json) });
  } else {
    // Uses GOOGLE_APPLICATION_CREDENTIALS (path to the service-account JSON).
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
}

/**
 * Send a push to every registered device. `data` carries the deep-link info
 * the app uses (e.g. {type:'application', uuid:'…'}). Invalid tokens are pruned.
 */
export async function sendPush(
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<number> {
  const tokens = store.tokens();
  if (tokens.length === 0) return 0;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  const dead: string[] = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code ?? '';
      if (
        code.includes('registration-token-not-registered') ||
        code.includes('invalid-argument') ||
        code.includes('invalid-registration-token')
      ) {
        const t = tokens[i];
        if (t) dead.push(t);
      }
    }
  });
  for (const t of dead) await store.removeToken(t);

  return res.successCount;
}
