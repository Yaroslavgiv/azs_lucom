'use strict';

/**
 * sessionStart — inject project context for azs_app.
 * Reads JSON from stdin, writes JSON to stdout.
 */
const fs = require('fs');

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

async function main() {
  await readStdin();
  const extra = [
    'Проект: azs_app — офлайн Flutter (Riverpod + sqflite + package excel).',
    'Excel только через lib/core/services/export_service.dart.',
    'Скиллы: .cursor/skills/ (excel-export, seed-pipeline, maps-geo, add-feature).',
    'Команды: /analyze, /excel-export, /new-feature, /seed-update, /hot-reload, /review, /db-migrate.',
    'Секреты DaData в .env — не коммитить и не логировать.',
    'Отвечай пользователю по-русски.',
  ].join(' ');

  process.stdout.write(
    JSON.stringify({
      additional_context: extra,
    }),
  );
}

main().catch(() => {
  process.stdout.write('{}');
  process.exit(0);
});
