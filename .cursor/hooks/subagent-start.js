'use strict';

/**
 * subagentStart — inject role hints for Task subagents.
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

async function main() {
  let input = {};
  try {
    input = JSON.parse(await readStdin() || '{}');
  } catch {
    process.stdout.write(JSON.stringify({ permission: 'allow' }));
    return;
  }

  const subagentType = String(input.subagent_type || input.subagentType || '');
  const hints = {
    explore:
      'azs_app: ищи в lib/features, lib/core. Excel = export_service.dart. Ответ по-русски, только чтение.',
    generalPurpose:
      'azs_app: feature-first + Riverpod. Excel через ExportService. Seed bump при JSON. Читай AGENTS.md / нужный skill.',
    shell:
      'azs_app: предпочитай flutter analyze / test / pub get. Не force push, не коммить .env.',
    'security-review':
      'Проверь DaData/.env в assets, утечки ключей, vendored ntk_map_view.',
    bugbot: 'Ревью diff azs_app с фокусом на offline DB и Excel export.',
  };

  const tip = hints[subagentType];
  const out = { permission: 'allow' };
  if (tip) {
    out.user_message = tip;
  }
  process.stdout.write(JSON.stringify(out));
}

main().catch(() => {
  process.stdout.write(JSON.stringify({ permission: 'allow' }));
});
