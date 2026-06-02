function normaliseBase(url: string): string {
  const trimmed = url.replace(/\/+$/, '').replace(/\/api\/v1$/, '');
  return `${trimmed}/api/v1`;
}

export const config = {
  port: Number(process.env.PORT ?? 8090),
  host: process.env.HOST ?? '0.0.0.0',

  /** Coolify base URL (with or without /api/v1) — normalised to include it. */
  coolifyApi: normaliseBase(process.env.COOLIFY_URL ?? ''),
  coolifyToken: process.env.COOLIFY_TOKEN ?? '',

  pollSeconds: Number(process.env.POLL_SECONDS ?? 30),

  /** Optional shared secret required on /register (sent as `x-register-secret`). */
  registerSecret: process.env.REGISTER_SECRET ?? '',

  /** Where the token/state JSON is kept (mount a volume here in production). */
  dataDir: process.env.DATA_DIR ?? './data',
};

export function assertConfig(): void {
  const missing: string[] = [];
  if (!process.env.COOLIFY_URL) missing.push('COOLIFY_URL');
  if (!config.coolifyToken) missing.push('COOLIFY_TOKEN');
  if (
    !process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 &&
    !process.env.GOOGLE_APPLICATION_CREDENTIALS
  ) {
    missing.push('FIREBASE_SERVICE_ACCOUNT_BASE64 or GOOGLE_APPLICATION_CREDENTIALS');
  }
  if (missing.length) {
    throw new Error(`Missing required env: ${missing.join(', ')}`);
  }
}
