/**
 * Copy staffhub-cms/.next to repo root so Vercel finalization finds .next/package.json
 * when the project Root Directory is the monorepo root (not staffhub-cms).
 */
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'staffhub-cms', '.next');
const dest = path.join(__dirname, '..', '.next');

if (!fs.existsSync(src)) {
  console.error('[vercel-sync] Missing staffhub-cms/.next — run build in staffhub-cms first.');
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log('[vercel-sync] Copied staffhub-cms/.next → .next');
