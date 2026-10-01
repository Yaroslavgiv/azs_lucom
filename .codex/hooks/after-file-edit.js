'use strict';

/**
 * afterFileEdit — remind about seed bump / excel single source of truth.
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

function context(msg) {
  process.stdout.write(JSON.stringify({ additional_context: msg }));
}

async function main() {
  let input = {};
  try {
    input = JSON.parse(await readStdin() || '{}');
  } catch {
    process.stdout.write('{}');
    return;
  }

  const file =
    String(input.filePath || input.path || input.file || '').replace(/\\/g, '/');

  if (/assets\/(stations_yandex|operational_data|station_equipment)\.json$/i.test(file)) {
    context(
      'Изменён seed JSON. Обязательно bump версии в соответствующем *SeedService (_seedVersion/_dataVersion), иначе обновление не применится на существующих установках.',
    );
    return;
  }

  if (/lib\/features\/export\//i.test(file) && !/export_service\.dart$/i.test(file)) {
    context(
      'UI экспорта: генерация xlsx должна оставаться в lib/core/services/export_service.dart (skill excel-export).',
    );
    return;
  }

  if (/lib\/core\/database\/app_database\.dart$/i.test(file)) {
    context(
      'Схема sqflite: проверь bump version и ветку onUpgrade для существующих пользователей.',
    );
    return;
  }

  process.stdout.write('{}');
}

main().catch(() => {
  process.stdout.write('{}');
});
