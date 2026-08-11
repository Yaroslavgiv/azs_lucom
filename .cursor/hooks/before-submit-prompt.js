'use strict';

/**
 * beforeSubmitPrompt — soft-warn if user pastes secrets.
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
    process.stdout.write('{}');
    return;
  }

  const prompt = String(input.prompt || input.content || '');
  const patterns = [
    /DADATA_TOKEN\s*=\s*(?!your_token_here)(\S{8,})/i,
    /DADATA_SECRET\s*=\s*(?!your_secret_here)(\S{8,})/i,
    /Token\s+[a-f0-9]{32,}/i,
  ];

  if (patterns.some((re) => re.test(prompt))) {
    process.stdout.write(
      JSON.stringify({
        continue: true,
        user_message:
          'В промпте похоже на секреты DaData. Не коммитьте их; ротируйте ключ, если уже засветился.',
        agent_message:
          'Пользователь вставил возможный секрет. Не повторяй значения токенов в ответе и не пиши их в файлы репозитория.',
      }),
    );
    return;
  }

  process.stdout.write(JSON.stringify({ continue: true }));
}

main().catch(() => {
  process.stdout.write(JSON.stringify({ continue: true }));
});
