const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { applyTransition, redactLog } = require('./workflow');

initializeApp();

function log(correlationId, message) {
  console.log(JSON.stringify({
    correlationId,
    message: redactLog(message),
  }));
}

exports.applyWorkCommand = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Требуется вход');
  }
  const data = request.data || {};
  const correlationId = data.correlation_id || 'none';
  const db = getFirestore();
  const profileSnap = await db.collection('users').doc(request.auth.uid).get();
  if (!profileSnap.exists) {
    throw new HttpsError('permission-denied', 'Профиль не найден');
  }
  const profile = profileSnap.data();
  const remoteId = data.remote_id;
  if (!remoteId || !data.target_entity) {
    throw new HttpsError('invalid-argument', 'Не указана целевая запись');
  }
  const ref = db.collection(data.target_entity).doc(remoteId);
  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Запись не найдена');
      }
      const current = snap.data();
      const decision = applyTransition({
        kind: data.kind,
        currentStatus: current.workflow_status,
        action: data.action,
        role: profile.role,
        actorId: request.auth.uid,
        assigneeId: current.assignee_id,
        comment: data.comment,
        commandKey: data.command_key,
        lastCommandKey: current.last_command_key,
        baseRevision: data.base_revision,
        currentRevision: current.revision || 0,
        requiresReview: current.requires_review === true || current.requires_review === 1,
      });
      if (!decision.ok) {
        const code = decision.conflict ? 'failed-precondition' : 'permission-denied';
        throw new HttpsError(code, decision.denial);
      }
      if (!decision.idempotent) {
        tx.update(ref, {
          workflow_status: decision.status,
          status: decision.legacyStatus,
          assignee_id: data.assignee_id || current.assignee_id || null,
          due_at: data.due_at || current.due_at || null,
          revision: (current.revision || 0) + 1,
          last_command_key: data.command_key,
          updated_at: FieldValue.serverTimestamp(),
        });
        const auditRef = db.collection('audit_events').doc();
        tx.set(auditRef, {
          actor_id: request.auth.uid,
          entity_type: data.kind,
          entity_id: remoteId,
          action: data.action,
          previous_value: current.workflow_status || null,
          new_value: decision.status,
          created_at: new Date().toISOString(),
          management_id: current.management_id || profile.management_id || null,
          correlation_id: correlationId,
        });
        if (data.assignee_id) {
          const eventKey = `${data.action}:${remoteId}:${data.assignee_id}`;
          tx.set(db.collection('notifications').doc(eventKey), {
            recipient_id: data.assignee_id,
            event_key: eventKey,
            type: data.action,
            entity_type: data.kind,
            entity_id: remoteId,
            title: data.action,
            body: '',
            created_at: new Date().toISOString(),
          }, { merge: true });
        }
      }
      return decision;
    });
    log(correlationId, `command ${data.action} applied`);
    return { status: result.status, idempotent: result.idempotent === true };
  } catch (error) {
    log(correlationId, `command failed ${error.message || error}`);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'Команда не выполнена');
  }
});
