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
};

test('manual assignment is denied', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'created',
    action: 'assign',
    assigneeId: 'spec',
  });
  assert.equal(result.ok, false);
  assert.equal(result.denial, 'Назначение вручную недоступно');
});

test('specialist closes a request without review', () => {
  const result = applyTransition({
    ...base,
    role: 'specialist',
    actorId: 'spec',
    assigneeId: 'spec',
    currentStatus: 'in_progress',
    action: 'complete',
  });
  assert.equal(result.ok, true);
  assert.equal(result.status, 'closed');
  assert.equal(result.legacyStatus, 'closed');
});

test('review rule blocks completion', () => {
  const result = applyTransition({
    ...base,
    role: 'specialist',
    actorId: 'spec',
    assigneeId: 'spec',
    currentStatus: 'in_progress',
    action: 'complete',
    requiresReview: true,
  });
  assert.equal(result.ok, false);
  assert.equal(result.denial, 'Заявка требует проверки руководителя');
});

test('specialist records maintenance once', () => {
  const done = applyTransition({
    ...base,
    kind: 'maintenance',
    role: 'specialist',
    actorId: 'spec',
    assigneeId: 'spec',
    currentStatus: 'not_done',
    action: 'complete',
  });
  assert.equal(done.status, 'done');
  assert.equal(done.legacyStatus, 'done');
  const again = applyTransition({
    ...base,
    kind: 'maintenance',
    role: 'specialist',
    actorId: 'spec',
    assigneeId: 'spec',
    currentStatus: 'done',
    action: 'complete',
    commandKey: 'other',
  });
  assert.equal(again.idempotent, true);
});

test('legacy head can still accept', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'on_review',
    action: 'accept',
    commandKey: 'accept-1',
  });
  assert.equal(result.ok, true);
  assert.equal(result.status, 'accepted');
});

test('specialist cannot accept', () => {
  const result = applyTransition({
    ...base,
    role: 'specialist',
    actorId: 'spec',
    assigneeId: 'spec',
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
    assigneeId: 'spec',
  });
  assert.equal(result.idempotent, true);
  assert.equal(result.status, 'assigned');
});

test('stale revision is a conflict', () => {
  const result = applyTransition({
    ...base,
    currentStatus: 'on_review',
    action: 'accept',
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
