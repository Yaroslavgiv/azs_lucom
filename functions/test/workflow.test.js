const test = require('node:test');
const assert = require('node:assert/strict');
const { applyTransition, redactLog } = require('../src/workflow');

const base = {
  kind: 'request',
  role: 'department_head',
  actorId: 'head',
  commandKey: 'k1',
  baseRevision: 0,
  currentRevision: 0,
  checklistComplete: true,
};

test('leader assigns a new request', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'created',
    action: 'assign',
    assigneeId: 'spec',
  });
  assert.equal(result.ok, true);
  assert.equal(result.status, 'assigned');
  assert.equal(result.legacyStatus, 'open');
});

test('specialist cannot accept', () => {
  const result = applyTransition({
    ...base,
    role: 'specialist',
    actorId: 'spec',
    currentStatus: 'on_review',
    action: 'accept',
  });
  assert.equal(result.ok, false);
});

test('return requires a comment', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'on_review',
    action: 'returnForRework',
    comment: '  ',
  });
  assert.equal(result.denial, 'Возврат требует комментарий');
});

test('same command key is idempotent', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'assigned',
    action: 'start',
    lastCommandKey: 'k1',
    commandKey: 'k1',
  });
  assert.equal(result.idempotent, true);
  assert.equal(result.status, 'assigned');
});

test('stale revision is a conflict', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'created',
    action: 'assign',
    assigneeId: 'spec',
    baseRevision: 1,
    currentRevision: 2,
  });
  assert.equal(result.conflict, true);
});

test('repeated accept does not create a new status', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'accepted',
    action: 'accept',
    commandKey: 'other',
  });
  assert.equal(result.idempotent, true);
  assert.equal(result.status, 'accepted');
});

test('logs do not keep secrets', () => {
  const text = redactLog('Authorization: Bearer secret-token password=qwerty');
  assert.equal(text.includes('secret-token'), false);
  assert.equal(text.includes('qwerty'), false);
});
