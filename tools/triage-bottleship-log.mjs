// Classifies log evidence; does not infer success from missing log messages.
// Accepts a plaintext "Load Recent" export; never uploads or echoes log lines.
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

export const RULES = Object.freeze({
  device: /\b(?:Direct3DCreate9|CreateDevice(?:Ex)?|D3D9 device|device created)\b/i,
  draw: /\b(?:DrawPrimitive(?:UP)?|DrawIndexedPrimitive(?:UP)?|draw calls?\s*[:=]\s*[1-9]\d*)\b/i,
  present: /\b(?:Present(?:Ex)?|presents?\s*[:=]\s*\d+)\b/i,
  resource: /\b(?:CreateTexture|CreateVertexBuffer|CreateIndexBuffer|SetTexture|D3DXCreateTexture)\b/i,
  file: /\b(?:CreateFile[AW]|ReadFile|file (?:not found|missing)|ENOENT|ERROR_FILE_NOT_FOUND)\b/i,
  fault: /\b(?:Unhandled access violation|illegal instruction|uncaught|fatal error|bootloader escape)\b/i,
  failure: /\b(?:D3DERR_[A-Z_]+|E_FAIL\b|HRESULT\s*[:=]\s*0x800[0-9a-f]{5}|file not found|ERROR_FILE_NOT_FOUND)\b/i,
});
export function newSummary() {
  return {
    totalLines: 0, categories: Object.fromEntries(Object.keys(RULES).map(k => [k, 0])),
    firstLine: Object.fromEntries(Object.keys(RULES).map(k => [k, null])),
    lastLine: Object.fromEntries(Object.keys(RULES).map(k => [k, null])),
    limitations: 'Matches show log mentions, not verified API success. Zero matches may mean logging is disabled. No game/menu state is inferred.',
  };
}
export function addLine(summary, line) {
  summary.totalLines += 1;
  for (const [name, re] of Object.entries(RULES)) {
    if (re.test(line)) {
      summary.categories[name]++;
      if (summary.firstLine[name] === null) summary.firstLine[name] = summary.totalLines;
      summary.lastLine[name] = summary.totalLines;
    }
  }
  return summary;
}
export async function summarizeFile(filename) {
  const summary = newSummary();
  for await (const line of createInterface({ input: createReadStream(filename), crlfDelay: Infinity })) {
    addLine(summary, line);
  }
  return summary;
}
if (process.argv[1] && import.meta.url === new URL('file://' + process.argv[1].replaceAll('\\', '/')).href) {
  const filename = process.argv[2];
  if (!filename) {
    console.error('Usage: node tools/triage-bottleship-log.mjs <local-log.txt>');
    process.exitCode = 2;
  } else {
    summarizeFile(filename).then(s => console.log(JSON.stringify(s, null, 2))).catch(err => {
      console.error('Unable to read the local log:', err.code || err.name);
      process.exitCode = 1;
    });
  }
}
