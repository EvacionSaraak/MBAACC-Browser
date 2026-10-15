import { test } from 'vitest';
import { strict as assert } from 'node:assert';
import { newSummary, addLine } from '../tools/triage-bottleship-log.mjs';

test('classifies rendering, file access and fatal faults without retaining log data', () => {
  const s = newSummary();
  const lines = [
    '[D3D] Direct3DCreate9 initialized',
    'CreateFileA C:\\private\\game\\secret.p',
    'Present()',
    'D3DERR_INVALIDCALL after CreateTexture',
    'Unhandled access violation',
  ];
  for (const line of lines) addLine(s, line);
  assert.equal(s.totalLines, 5);
  for (const k of ['device', 'present', 'resource', 'file', 'failure', 'fault']) assert.equal(s.categories[k], 1);
  assert.equal(s.categories.draw, 0);
  assert.equal(s.firstLine.fault, 5);
  assert.ok(!JSON.stringify(s).includes('secret.p'));
});
test('zero matches are explicitly inconclusive, not proof of missing execution', () => {
  const s = addLine(newSummary(), 'heartbeat tick');
  assert.equal(s.categories.device, 0);
  assert.match(s.limitations, /Zero matches may mean logging is disabled/);
});
