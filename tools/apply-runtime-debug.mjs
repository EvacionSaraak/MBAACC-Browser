// Source-only helper: never opens a game installation or installs software.
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
export const BOTTLESHIP_REVISION = '2e1746cdf196a0b57d605ac3519040cc2a1f9406';
const args = process.argv.slice(2);
const apply = args.includes('--apply');
const paths = args.filter(a => a !== '--apply');
if (paths.length !== 1) throw new Error('Usage: node tools/apply-runtime-debug.mjs [--apply] <BottleShip-checkout>');
const checkout = resolve(paths[0]);
const patch = fileURLToPath(new URL('../runtime/bottleship-callback-flow.patch', import.meta.url));
const git = process.env.GIT || 'git';
function run(command) {
  const result = spawnSync(git, ['-C', checkout, ...command], {encoding: 'utf8'});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || `Git failed: ${command.join(' ')}`);
  return result.stdout.trim();
}
if (run(['rev-parse', 'HEAD']) !== BOTTLESHIP_REVISION) throw new Error(`Expected BottleShip ${BOTTLESHIP_REVISION}. Use a separate checkout at that revision.`);
if (run(['status', '--porcelain', '--untracked-files=no'])) throw new Error('Tracked source changes exist. Use a clean checkout; this helper will not reset them.');
run(['apply', '--check', patch]);
if (apply) run(['apply', patch]);
console.log(apply ? 'Pinned runtime diagnostics, tested startup fixes, and synthetic tests applied. Main-menu compatibility is not established.' : 'Patch validated; pass --apply to apply the source instrumentation.');
