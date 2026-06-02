import { config } from './config.js';
import * as coolify from './coolify.js';
import { sendPush } from './fcm.js';
import { store } from './store.js';

type Logger = { info: (m: string) => void; error: (m: string) => void };

const TERMINAL = new Set(['finished', 'failed', 'cancelled-by-user', 'cancelled']);

async function pollHealth(log: Logger, seeding: boolean): Promise<void> {
  const list = await coolify.resources();
  const prev = store.health();
  const next: Record<string, string> = {};

  for (const r of list) {
    if (!r.uuid) continue;
    const lvl = coolify.healthLevel(r.status);
    next[r.uuid] = lvl;
    if (seeding) continue;

    const was = prev[r.uuid];
    const wasGood = was === undefined || was === 'healthy' || was === 'other';
    const nowBad = lvl === 'warning' || lvl === 'down';
    // Notify on a healthy/unknown -> bad transition only.
    if (was !== undefined && wasGood && nowBad) {
      const name = r.name ?? 'Resource';
      const label = lvl === 'down' ? 'is down' : 'is unhealthy';
      await sendPush(`${name} ${label}`, `Status: ${r.status ?? 'unknown'}`, {
        type: coolify.resourceKind(r.type),
        uuid: r.uuid,
      });
      log.info(`notified: ${name} -> ${lvl}`);
    }
  }
  await store.setHealth(next);
}

async function pollDeployments(log: Logger, seeding: boolean): Promise<void> {
  const apps = await coolify.applications();
  const notified = store.notified();
  const freshlyNotified: string[] = [];

  for (const a of apps) {
    if (!a.uuid) continue;
    let deps: coolify.DeploymentItem[];
    try {
      deps = await coolify.appDeployments(a.uuid);
    } catch (e) {
      log.error(`deploy history ${a.name}: ${String(e)}`);
      continue;
    }
    for (const d of deps) {
      const du = d.deployment_uuid;
      if (!du) continue;
      const status = (d.status ?? '').toLowerCase();
      if (!TERMINAL.has(status)) continue;
      if (notified.has(du) || freshlyNotified.includes(du)) continue;

      if (!seeding) {
        const verb =
          status === 'finished'
            ? 'finished'
            : status === 'failed'
              ? 'failed'
              : 'cancelled';
        await sendPush(
          `Deploy ${verb} · ${a.name ?? 'app'}`,
          d.commit_message ?? '',
          { type: 'application', uuid: a.uuid },
        );
        log.info(`notified: deploy ${verb} ${a.name}`);
      }
      freshlyNotified.push(du);
    }
  }
  if (freshlyNotified.length) await store.markNotified(freshlyNotified);
}

export async function tick(log: Logger): Promise<void> {
  // First ever run: record current state without sending, so we don't notify
  // about pre-existing unhealthy resources or old deployments.
  const seeding = !store.initialized();
  try {
    await pollHealth(log, seeding);
  } catch (e) {
    log.error(`health poll failed: ${String(e)}`);
  }
  try {
    await pollDeployments(log, seeding);
  } catch (e) {
    log.error(`deploy poll failed: ${String(e)}`);
  }
  if (seeding) {
    await store.setInitialized();
    log.info('seeded initial state (no notifications sent)');
  }
}

export function startWatcher(log: Logger): void {
  const run = async () => {
    await tick(log);
    setTimeout(run, config.pollSeconds * 1000);
  };
  run();
}
