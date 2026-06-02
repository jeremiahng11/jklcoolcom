import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { config } from './config.js';

interface Db {
  tokens: string[];
  /** uuid -> last health level (healthy|warning|down|other). */
  health: Record<string, string>;
  /** deployment_uuid -> last status. */
  deployments: Record<string, string>;
  /** deployment_uuids we've already notified about (terminal). */
  notified: string[];
  initialized: boolean;
}

const empty: Db = {
  tokens: [],
  health: {},
  deployments: {},
  notified: [],
  initialized: false,
};

let db: Db = { ...empty };
const file = join(config.dataDir, 'store.json');

export async function load(): Promise<void> {
  try {
    await mkdir(config.dataDir, { recursive: true });
    const raw = await readFile(file, 'utf8');
    db = { ...empty, ...JSON.parse(raw) };
  } catch {
    // first run — keep defaults
  }
}

async function save(): Promise<void> {
  await writeFile(file, JSON.stringify(db, null, 2));
}

export const store = {
  tokens: () => db.tokens,
  async addToken(t: string) {
    if (!db.tokens.includes(t)) {
      db.tokens.push(t);
      await save();
    }
  },
  async removeToken(t: string) {
    db.tokens = db.tokens.filter((x) => x !== t);
    await save();
  },

  health: () => db.health,
  async setHealth(h: Record<string, string>) {
    db.health = h;
    await save();
  },

  deployments: () => db.deployments,
  async setDeployments(d: Record<string, string>) {
    db.deployments = d;
    await save();
  },

  notified: () => new Set(db.notified),
  async markNotified(uuids: string[]) {
    const set = new Set([...db.notified, ...uuids]);
    // keep it bounded
    db.notified = [...set].slice(-2000);
    await save();
  },

  initialized: () => db.initialized,
  async setInitialized() {
    db.initialized = true;
    await save();
  },
};
