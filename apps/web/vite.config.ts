import tailwindcss from '@tailwindcss/postcss';
import vinext from 'vinext';
import { defineConfig } from 'vite';

const usePolling = process.env.FITCALGARY_VITE_USE_POLLING === 'true';

const deploymentVars: Record<string, string> =
  process.env.FITCALGARY_DEPLOY_TARGET === 'production'
    ? {
        WEB_PUBLIC_URL: 'https://fitcalgary-web.fitcalgary.workers.dev',
        NEXT_PUBLIC_SITE_URL: 'https://fitcalgary-web.fitcalgary.workers.dev',
        API_BASE_URL:
          'https://fitcalgary-api-production.up.railway.app/api/v1',
        OIDC_ISSUER:
          'https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary',
        OIDC_WEB_CLIENT_ID: 'fitcalgary-web',
      }
    : {};

const localBindingConfig = {
  name: 'fitcalgary-web',
  main: 'vinext/server/fetch-handler',
  compatibility_date: '2026-05-15',
  compatibility_flags: ['nodejs_compat', 'nodejs_compat_populate_process_env'],
  vars: deploymentVars,
  d1_databases: [],
  r2_buckets: [],
};

export default defineConfig(async () => {
  // Keep Wrangler and Miniflare state project-local. These are non-secret tool
  // settings; application environment belongs in ignored `.env*` files.
  process.env.WRANGLER_WRITE_LOGS ??= 'false';
  process.env.WRANGLER_LOG_PATH ??= '.wrangler/logs';
  process.env.MINIFLARE_REGISTRY_PATH ??= '.wrangler/registry';

  // Wrangler snapshots its log path while the Cloudflare plugin is imported.
  const { cloudflare } = await import('@cloudflare/vite-plugin');

  return {
    css: { postcss: { plugins: [tailwindcss()] } },
    server: usePolling
      ? { watch: { useFsEvents: false, usePolling: true } }
      : undefined,
    plugins: [
      vinext(),
      cloudflare({
        viteEnvironment: { name: 'rsc', childEnvironments: ['ssr'] },
        config: localBindingConfig,
      }),
    ],
  };
});
