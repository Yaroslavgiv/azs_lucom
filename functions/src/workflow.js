const requestTransitions = {
  created: { assign: 'assigned', cancel: 'cancelled' },
  assigned: { start: 'in_progress', reassign: 'assigned' },
  in_progress: { submit: 'on_review' },
  on_review: { accept: 'accepted', returnForRework: 'returned' },
  returned: { resume: 'in_progress', submit: 'on_review' },
};

const maintenanceTransitions = {
  planned: { assign: 'assigned' },
  assigned: { start: 'in_progress', reassign: 'assigned' },
  in_progress: { submit: 'on_review' },
  on_review: { accept: 'accepted', returnForRework: 'returned' },
  returned: { resume: 'in_progress', submit: 'on_review' },
};

const leaderRoles = new Set(['manager', 'department_head', 'management_head']);
const leaderActions = new Set([
  'assign',
  'reassign',
  'accept',
  'returnForRework',
  'cancel',
]);
const specialistActions = new Set(['start', 'submit', 'resume']);

function redactLog(message) {
  return String(message)
    .replace(/authorization:\s*\S+(?:\s+\S+)?/gi, 'Authorization: [redacted]')
    .replace(/bearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(/(token["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/(password["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/(secret["\s:=]+)[^\s",}]+/gi, '$1[redacted]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted]');
}

function legacyRequestStatus(status) {
  return status === 'accepted' || status === 'cancelled' ? 'closed' : 'open';
}

function legacyMaintenanceStatus(status) {
  return status === 'accepted' ? 'done' : 'pending';
}

function applyTransition(input) {
  if (input.lastCommandKey && input.lastCommandKey === input.commandKey) {
    return { ok: true, idempotent: true, status: input.currentStatus };
  }
  const table = input.kind === 'maintenance' ? maintenanceTransitions : requestTransitions;
  const next = table[input.currentStatus]?.[input.action];
  if (!next) {
    if (input.action === 'accept' && input.currentStatus === 'accepted') {
      return { ok: true, idempotent: true, status: input.currentStatus };
    }
    return { ok: false, denial: 'Переход недоступен' };
  }
  if (leaderActions.has(input.action) && !leaderRoles.has(input.role)) {
    return { ok: false, denial: 'Операция доступна только руководителю' };
  }
  if (specialistActions.has(input.action)) {
    if (input.role !== 'specialist' || input.actorId !== input.assigneeId) {
      return { ok: false, denial: 'Исполнять может только назначенный специалист' };
    }
  }
  if (input.action === 'returnForRework' && !String(input.comment || '').trim()) {
    return { ok: false, denial: 'Возврат требует комментарий' };
  }
  if ((input.action === 'assign' || input.action === 'reassign') && !input.assigneeId) {
    return { ok: false, denial: 'Укажите исполнителя' };
  }
  if (input.action === 'submit' && input.checklistComplete === false) {
    return { ok: false, denial: 'Заполните обязательные пункты чек-листа' };
  }
  if (Number(input.baseRevision) !== Number(input.currentRevision)) {
    return { ok: false, denial: 'Конфликт версии', conflict: true };
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
};
