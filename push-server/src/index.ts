import Fastify from 'fastify';
import { assertConfig, config } from './config.js';
import { initFcm, sendPush } from './fcm.js';
import { load, store } from './store.js';
import { startWatcher } from './watcher.js';

async function main() {
  assertConfig();
  await load();
  initFcm();

  const app = Fastify({ logger: true });

  app.get('/health', async () => ({ status: 'ok' }));

  app.get('/status', async () => ({
    tokens: store.tokens().length,
    initialized: store.initialized(),
    coolify: config.coolifyApi,
    pollSeconds: config.pollSeconds,
  }));

  // Register a device's FCM token.
  app.post('/register', async (req, reply) => {
    if (config.registerSecret) {
      const secret = req.headers['x-register-secret'];
      if (secret !== config.registerSecret) {
        return reply.code(401).send({ error: 'unauthorized' });
      }
    }
    const body = req.body as { token?: string } | undefined;
    const token = body?.token?.trim();
    if (!token) return reply.code(400).send({ error: 'token required' });
    await store.addToken(token);
    return { ok: true, tokens: store.tokens().length };
  });

  app.post('/unregister', async (req, reply) => {
    const body = req.body as { token?: string } | undefined;
    const token = body?.token?.trim();
    if (!token) return reply.code(400).send({ error: 'token required' });
    await store.removeToken(token);
    return { ok: true };
  });

  // Send a test push to all registered devices.
  app.post('/test', async (req) => {
    const body = (req.body ?? {}) as {
      title?: string;
      body?: string;
      data?: Record<string, string>;
    };
    const sent = await sendPush(
      body.title ?? 'Test notification',
      body.body ?? 'Hello from your Coolify push server',
      body.data ?? {},
    );
    return { sent };
  });

  await app.listen({ port: config.port, host: config.host });
  startWatcher({
    info: (m) => app.log.info(m),
    error: (m) => app.log.error(m),
  });
  app.log.info(
    `watching ${config.coolifyApi} every ${config.pollSeconds}s`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
