import { config } from './config.js';

export interface ResourceSummary {
  uuid?: string;
  name?: string;
  type?: string;
  status?: string;
}

export interface DeploymentItem {
  deployment_uuid?: string;
  status?: string;
  commit_message?: string;
  updated_at?: string;
}

async function api<T>(path: string): Promise<T> {
  const res = await fetch(`${config.coolifyApi}${path}`, {
    headers: {
      Authorization: `Bearer ${config.coolifyToken}`,
      Accept: 'application/json',
    },
  });
  if (!res.ok) throw new Error(`Coolify ${path} -> HTTP ${res.status}`);
  return (await res.json()) as T;
}

export function resources(): Promise<ResourceSummary[]> {
  return api<ResourceSummary[]>('/resources');
}

export function applications(): Promise<ResourceSummary[]> {
  return api<ResourceSummary[]>('/applications');
}

export async function appDeployments(uuid: string): Promise<DeploymentItem[]> {
  const data = await api<{ deployments?: DeploymentItem[] } | DeploymentItem[]>(
    `/deployments/applications/${uuid}?take=3`,
  );
  if (Array.isArray(data)) return data;
  return data.deployments ?? [];
}

// --- helpers shared with the app's status logic ---

export function healthLevel(status: string | undefined): string {
  const s = (status ?? '').toLowerCase();
  if (s === 'degraded' || s.includes('unhealthy')) return 'warning';
  if (s.startsWith('running')) return 'healthy';
  if (
    s.startsWith('exited') ||
    s === 'stopped' ||
    s === 'dead' ||
    s === 'paused'
  ) {
    return 'down';
  }
  return 'other';
}

export function resourceKind(type: string | undefined): string {
  const t = (type ?? '').toLowerCase();
  if (t.includes('application')) return 'application';
  if (t.includes('service')) return 'service';
  if (
    /postgres|mysql|mariadb|mongodb|redis|keydb|dragonfly|clickhouse|database/.test(
      t,
    )
  ) {
    return 'database';
  }
  return 'unknown';
}
