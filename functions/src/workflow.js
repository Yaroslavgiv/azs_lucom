const requestTransitions = {
  unassigned: { cancel: 'cancelled' },
  created: { start: 'in_progress', complete: 'closed', cancel: 'cancelled' },
  assigned: { start: 'in_progress', complete: 'closed' },
  in_progress: { submit: 'on_review', complete: 'closed' },
  on_review: { accept: 'accepted', returnForRework: 'returned' },
  returned: { resume: 'in_progress', submit: 'on_review', complete: 'closed' },
};

const maintenanceOpen = new Set([
  'not_done',
  'planned',
  'assigned',
  'in_progress',
  'on_review',
  'returned',
]);

const leaderActions = new Set(['accept', 'returnForRework', 'cancel']);
const specialistActions = new Set(['start', 'submit', 'resume', 'complete']);

function redactLog(message) {
  return String(message)
    .replace(/authorization:\s*\S+(?:\s+\S+)?/gi, 'Authorization: [redacted]')
    .replace(/bearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(/(token["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/(password["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/(secret["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted]');
}

function normalizeRole(role) {
  if (role === 'department_head' || role === 'management_head' || role === 'manager') {
    return 'manager';
  }
  return role;
}

function legacyRequestStatus(status) {
  return status === 'accepted' || status === 'closed' || status === 'cancelled'
    ? 'closed'
    : 'open';
}

function legacyMaintenanceStatus(status) {
  return status === 'accepted' || status === 'done' ? 'done' : 'pending';
}

function nextStatus(input) {
  if (input.kind === 'maintenance') {
    if (input.action !== 'complete') return null;
    return maintenanceOpen.has(input.currentStatus) ? 'done' : null;
  }
  return requestTransitions[input.currentStatus]?.[input.action] || null;
}

function sameOutcome(input) {
  if (input.action === 'accept' && input.currentStatus === 'accepted') return true;
  if (
    input.action === 'complete' &&
    ['done', 'accepted', 'closed'].includes(input.currentStatus)
  ) {
    return true;
  }
  return false;
}

function applyTransition(input) {
  const role = normalizeRole(input.role);
  if (input.lastCommandKey && input.lastCommandKey === input.commandKey) {
    return { ok: true, idempotent: true, status: input.currentStatus };
  }
  if (Number(input.baseRevision) !== Number(input.currentRevision)) {
    return { ok: false, denial: 'Конфликт версии', conflict: true };
  }
  if (input.action === 'assign' || input.action === 'reassign') {
    return { ok: false, denial: 'Назначение вручную недоступно' };
  }
  if (input.kind === 'maintenance' && input.currentStatus === 'overdue') {
    return { ok: false, denial: 'Месяц закрыт как просроченный' };
  }
  const next = nextStatus(input);
  if (!next) {
    if (sameOutcome(input)) {
      return { ok: true, idempotent: true, status: input.currentStatus };
    }
    return { ok: false, denial: 'Переход недоступен' };
  }
  if (leaderActions.has(input.action) && role !== 'manager') {
    return { ok: false, denial: 'Операция доступна только руководителю' };
  }
  if (specialistActions.has(input.action)) {
    if (role !== 'specialist' || input.actorId !== input.assigneeId) {
      return { ok: false, denial: 'Исполнять может только назначенный специалист' };
    }
  }
  if (input.action === 'returnForRework' && !String(input.comment || '').trim()) {
    return { ok: false, denial: 'Возврат требует комментарий' };
  }
  if (input.action === 'complete' && input.kind !== 'maintenance' && input.requiresReview) {
    return { ok: false, denial: 'Заявка требует проверки руководителя' };
  }
  return {
    ok: true,
    idempotent: false,
    status: next,
    legacyStatus: input.kind === 'maintenance'
      ? legacyMaintenanceStatus(next)
      : legacyRequestStatus(next),
  };
}

module.exports = {
  applyTransition,
  redactLog,
  legacyRequestStatus,
  legacyMaintenanceStatus,
  normalizeRole,
};
