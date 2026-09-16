const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

function actorRole(profile) {
  return profile?.role || 'specialist';
}

async function loadProfile(uid) {
  const snap = await getFirestore().collection('users').doc(uid).get();
  return snap.exists ? snap.data() : null;
}

function assertManager(profile) {
  const role = actorRole(profile);
  if (role !== 'manager' && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Недостаточно прав.');
  }
}

function assertAdmin(profile) {
  if (actorRole(profile) !== 'admin') {
    throw new HttpsError('permission-denied', 'Нужна роль администратора.');
  }
}

async function writeAudit({ action, entity, entityId, actorId, actorName, summary, payload }) {
  await getFirestore().collection('audit_log').add({
    action,
    entity,
    entity_id: entityId,
    actor_id: actorId,
    actor_name: actorName || '',
    created_at: new Date().toISOString(),
    summary: summary || '',
    payload: payload || {},
    updated_at: FieldValue.serverTimestamp(),
  });
}

exports.acceptMaintenance = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Нужна авторизация.');
  }
  const profile = await loadProfile(request.auth.uid);
  assertManager(profile);
  const stationNumber = request.data?.stationNumber;
  const month = request.data?.month;
  const comment = request.data?.comment || '';
  if (!stationNumber || !month) {
    throw new HttpsError('invalid-argument', 'Нужны stationNumber и month.');
  }
  const id = `${stationNumber}_${month}`;
  const ref = getFirestore().collection('maintenance').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Запись ТО не найдена.');
  }
  const current = snap.data() || {};
  if (current.status === 'accepted' || current.status === 'done') {
    return { ok: true, idempotent: true, status: 'accepted' };
  }
  await ref.set(
    {
      ...current,
      station_number: stationNumber,
      month,
      status: 'accepted',
      reviewed_by: request.auth.uid,
      review_comment: comment,
      updated_by: request.auth.uid,
      updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await writeAudit({
    action: 'accept_maintenance',
    entity: 'maintenance',
    entityId: id,
    actorId: request.auth.uid,
    actorName: profile?.display_name || request.auth.token.email || '',
    summary: `ТО АЗС ${stationNumber} за ${month} принято`,
    payload: { comment },
  });
  return { ok: true, status: 'accepted' };
});

exports.returnMaintenance = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Нужна авторизация.');
  }
  const profile = await loadProfile(request.auth.uid);
  assertManager(profile);
  const stationNumber = request.data?.stationNumber;
  const month = request.data?.month;
  const comment = request.data?.comment || '';
  if (!stationNumber || !month) {
    throw new HttpsError('invalid-argument', 'Нужны stationNumber и month.');
  }
  const id = `${stationNumber}_${month}`;
  const ref = getFirestore().collection('maintenance').doc(id);
  await ref.set(
    {
      station_number: stationNumber,
      month,
      status: 'returned',
      reviewed_by: request.auth.uid,
      review_comment: comment,
      updated_by: request.auth.uid,
      updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await writeAudit({
    action: 'return_maintenance',
    entity: 'maintenance',
    entityId: id,
    actorId: request.auth.uid,
    actorName: profile?.display_name || request.auth.token.email || '',
    summary: `ТО АЗС ${stationNumber} за ${month} возвращено`,
    payload: { comment },
  });
  return { ok: true, status: 'returned' };
});

exports.createAppUser = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Нужна авторизация.');
  }
  const profile = await loadProfile(request.auth.uid);
  assertAdmin(profile);
  const email = String(request.data?.email || '').trim();
  const password = String(request.data?.password || '');
  const displayName = String(request.data?.displayName || email);
  const role = request.data?.role || 'specialist';
  const regions = Array.isArray(request.data?.regions)
    ? request.data.regions
    : ['spb', 'novgorod'];
  if (!email || password.length < 6) {
    throw new HttpsError('invalid-argument', 'Нужны email и пароль от 6 символов.');
  }
  const user = await getAuth().createUser({
    email,
    password,
    displayName,
  });
  await getFirestore().collection('users').doc(user.uid).set({
    email,
    display_name: displayName,
    role,
    regions,
    disabled: false,
    updated_at: FieldValue.serverTimestamp(),
  });
  await writeAudit({
    action: 'create_user',
    entity: 'users',
    entityId: user.uid,
    actorId: request.auth.uid,
    actorName: profile?.display_name || request.auth.token.email || '',
    summary: `Создан пользователь ${email} (${role})`,
    payload: { role, regions },
  });
  return { ok: true, uid: user.uid };
});
