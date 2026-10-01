'use strict';

/**
 * beforeShellExecution — block dangerous / secret-leaking commands.
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

function deny(userMessage, agentMessage) {
  process.stdout.write(
    JSON.stringify({
      permission: 'deny',
      user_message: userMessage,
      agent_message: agentMessage,
    }),
  );
}

function ask(userMessage, agentMessage) {
  process.stdout.write(
    JSON.stringify({
      permission: 'ask',
      user_message: userMessage,
      agent_message: agentMessage,
    }),
  );
}

function allow() {
  process.stdout.write(JSON.stringify({ permission: 'allow' }));
}

async function main() {
  let input = {};
  try {
    input = JSON.parse(await readStdin() || '{}');
  } catch {
    allow();
    return;
  }

  const cmd = String(input.command || '');
  const lower = cmd.toLowerCase();

  // Destructive git
  if (/\bgit\s+push\s+.*--force\b|\bgit\s+push\s+-f\b/.test(lower)) {
    deny(
      'Заблокирован force push.',
      'Hook: git push --force запрещён политикой проекта azs_app.',
    );
    return;
  }
  if (/\bgit\s+reset\s+--hard\b/.test(lower)) {
    deny(
      'Заблокирован git reset --hard.',
      'Hook: destructive reset запрещён без явного запроса вне hook (спроси пользователя).',
    );
    return;
  }

  // Committing secrets
  if (/\bgit\s+add\b/.test(lower) && /(^|[\s/\\])\.env([\s"']|$)/.test(cmd)) {
    deny(
      'Нельзя добавлять .env в git.',
      'Hook: отказ — .env может содержать DADATA_TOKEN/SECRET.',
    );
    return;
  }
  if (
    /\bgit\s+(commit|add)\b/.test(lower) &&
    /(\.jks|\.keystore|key\.properties|google-services\.json)/i.test(cmd)
  ) {
    deny(
      'Заблокировано добавление/коммит keystore или google-services.',
      'Hook: чувствительные Android/iOS credential-файлы.',
    );
    return;
  }

  // Network exfil-ish one-liners with .env
  if (
    /(curl|wget|Invoke-WebRequest|invoke-restmethod)/i.test(cmd) &&
    /\.env|dadata_token|dadata_secret/i.test(cmd)
  ) {
    deny(
      'Заблокирована сетевая команда с упоминанием секретов/.env.',
      'Hook: возможная утечка DaData credentials.',
    );
    return;
  }

  // Confirm flutter clean as disruptive
  if (/\bflutter\s+clean\b/.test(lower)) {
    ask(
      'Подтвердите flutter clean (долго пересобирает).',
      'Hook: flutter clean просит подтверждение.',
    );
    return;
  }

  allow();
}

main().catch(() => {
  process.stdout.write(JSON.stringify({ permission: 'allow' }));
});
