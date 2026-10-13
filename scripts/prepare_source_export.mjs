#!/usr/bin/env node
// Create an isolated, tracked-source export. This command never pushes or rewrites Git.
import {execFileSync} from 'node:child_process';
import {mkdirSync, existsSync, readdirSync, readFileSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const destination = process.argv[2];
if (!destination || !path.isAbsolute(destination) || existsSync(destination)) {
  throw new Error('Supply a new absolute export directory. Existing folders are never overwritten.');
}
if (destination === root || destination.startsWith(root + path.sep)) {
  throw new Error('Export must be outside the source repository.');
}
const excludes = new Set([
  'docs/BLOCKERS.md', 'docs/CONTRACT_GAP_AUDIT.md', 'docs/CONTRACT_PHASE_STATUS.md',
  'docs/CURRENT_PROGRESS.md', 'docs/FINAL_DELIVERY_SUMMARY.md',
  'docs/IMPLEMENTATION_STATUS.md', 'docs/PHASE2_EXECUTION_STATUS.md',
  'docs/PHASE3_EXECUTION_STATUS.md', 'docs/PRODUCTION_STABILIZATION_AUDIT.md',
  'docs/TEST_MATRIX.md', 'docs/ZERO_COST_MIGRATION.md',
  'docs/FINAL_RELEASE_MATRIX.md', 'docs/PRODUCTION_VERIFICATION.md',
  'docs/STORE_SUBMISSION_PREPARATION.md',
  'docs/SOURCE_HANDOFF_STATUS.md',
  'scripts/prepare_source_export.mjs', 'scripts/prepare_phase2_review_assets.py',
  'scripts/test_free_vm_restore.mjs', 'scripts/snapshot_migration_config.mjs',
]);
const omitted = p => p.startsWith('client-review/') || p.startsWith('artifacts/') || p.startsWith('brand/generated/') ||
  p.startsWith('.railway/') || p.startsWith('docs/PHASE_') ||
  /^scripts\/build_phase\d/.test(p) || excludes.has(p);
const files = execFileSync('git', ['ls-files', '-z'], {cwd: root}).toString().split('\0')
  .filter(p => p && !omitted(p));
if (files.length < 300) throw new Error('Export unexpectedly lacks product source.');
mkdirSync(destination, {mode: 0o700});
const archive = execFileSync('git', ['archive', '--format=tar', 'HEAD', '--', ...files],
  {cwd: root, maxBuffer: 128 * 1024 * 1024});
execFileSync('tar', ['-xf', '-', '-C', destination], {input: archive});
// Keep pixels and colour profiles intact, remove only nonfunctional image metadata.
function stripPng(file) {
  const data = readFileSync(file);
  if (!data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return;
  const chunks = [data.subarray(0, 8)];
  let removed = 0;
  for (let offset = 8; offset < data.length;) {
    const length = data.readUInt32BE(offset);
    const end = offset + length + 12;
    if (end > data.length) throw new Error('Invalid PNG structure');
    const type = data.toString('ascii', offset + 4, offset + 8);
    const attribution = ['tEXt','iTXt','zTXt'].includes(type) &&
      /copyright|licen[cs]e|attribution/i.test(data.toString('utf8', offset + 8, end - 4));
    if (!attribution && ['caBX','tEXt','zTXt','iTXt','tIME'].includes(type)) removed++;
    else chunks.push(data.subarray(offset, end));
    offset = end;
  }
  if (removed) writeFileSync(file, Buffer.concat(chunks));
}
function walk(dir) {
  for (const entry of readdirSync(dir, {withFileTypes: true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('.png')) stripPng(file);
  }
}
walk(destination);
console.log(`Isolated source export prepared: ${files.length} tracked files. No private Git directory copied.`);
