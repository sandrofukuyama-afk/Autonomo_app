import type { VercelRequest, VercelResponse } from '@vercel/node';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

function json(res: VercelResponse, data: unknown, status = 200) {
  res.status(status).setHeader('Content-Type', 'application/json');
  res.send(JSON.stringify(data));
}

async function readBody(req: VercelRequest): Promise<any> {
  if (req.body) return req.body;

  return new Promise((resolve) => {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      try {
        resolve(JSON.parse(body));
      } catch {
        resolve({});
      }
    });
  });
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return json(res, { error: 'method_not_allowed' }, 405);
  }

  if (!OPENAI_API_KEY) {
    return json(res, { error: 'missing_openai_key' }, 500);
  }

  const body = await readBody(req);
  const question = body?.question ?? '';
  const language = body?.language ?? 'pt';

  if (!question) {
    return json(res, { error: 'missing_question' }, 400);
  }

  const systemPrompt = `
Você é um assistente do Autonomo App.

O aplicativo é usado por trabalhadores autônomos no Japão para:

- registrar receitas
- registrar despesas
- anexar recibos
- revisar despesas fiscais
- gerar relatório fiscal
- preparar declaração Blue Return

Você pode explicar:

- como usar o aplicativo
- categorias de despesas
- impostos básicos no Japão
- diferença entre 税込 e 税抜
- quando anexar recibo
- como funciona revisão fiscal

Nunca invente regras fiscais.
Nunca dê aconselhamento legal definitivo.
Responda no idioma solicitado.
`;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.3,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: question },
        ],
      }),
    });

    const data = await response.json();

    const answer =
      data?.choices?.[0]?.message?.content ??
      'Não consegui gerar resposta no momento.';

    return json(res, { answer });
  } catch (error) {
    console.error(error);
    return json(res, { error: 'ai_request_failed' }, 500);
  }
}
