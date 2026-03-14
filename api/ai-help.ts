import type { VercelRequest, VercelResponse } from '@vercel/node';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

function sendJson(res: VercelResponse, status: number, data: unknown) {
  res.status(status);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.send(JSON.stringify(data));
}

async function readBody(req: VercelRequest): Promise<any> {
  if (req.body && typeof req.body === 'object') return req.body;

  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        resolve({});
      }
    });
  });
}

function buildSystemPrompt(language: string) {
  return `
Você é o assistente de ajuda do Autonomo App.

Contexto do produto:
- app para autônomos no Japão
- controla entradas, despesas, recibos, OCR, revisão fiscal, fechamento de mês e relatório fiscal
- responde dúvidas sobre uso do app e conceitos fiscais básicos do Japão
- pode explicar diferença entre 税込 e 税抜, categorias de despesas, revisão fiscal, fechamento mensal, recibos e OCR

Regras:
- responda no idioma solicitado: ${language}
- seja objetivo e claro
- não invente regras fiscais
- não dê aconselhamento legal definitivo
- quando houver dúvida fiscal sensível, diga que a resposta é informativa e pode exigir confirmação contábil

Formato:
- resposta curta, útil e direta
`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return sendJson(res, 405, { error: 'method_not_allowed' });
  }

  if (!OPENAI_API_KEY) {
    return sendJson(res, 500, {
      error: 'missing_openai_key',
      message: 'OPENAI_API_KEY não configurada no Vercel.',
    });
  }

  try {
    const body = await readBody(req);
    const question = (body?.question ?? '').toString().trim();
    const language = (body?.language ?? 'pt').toString().trim();

    if (!question) {
      return sendJson(res, 400, {
        error: 'missing_question',
        message: 'Pergunta não informada.',
      });
    }

    const apiResponse = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: buildSystemPrompt(language),
              },
            ],
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: question,
              },
            ],
          },
        ],
        temperature: 0.3,
      }),
    });

    const rawText = await apiResponse.text();
    let data: any = null;

    try {
      data = rawText ? JSON.parse(rawText) : {};
    } catch {
      return sendJson(res, 502, {
        error: 'invalid_openai_response',
        message: 'Resposta inválida da OpenAI.',
        raw: rawText,
      });
    }

    if (!apiResponse.ok) {
      return sendJson(res, apiResponse.status, {
        error: 'openai_request_failed',
        message:
          data?.error?.message ??
          'A OpenAI retornou erro ao processar a solicitação.',
        type: data?.error?.type ?? null,
        code: data?.error?.code ?? null,
      });
    }

    const answer =
        data?.output_text?.toString().trim() ||
        data?.output?.[0]?.content?.[0]?.text?.toString().trim() ||
        '';

    if (!answer) {
      return sendJson(res, 502, {
        error: 'empty_ai_answer',
        message: 'A IA não retornou texto.',
        debug: data,
      });
    }

    return sendJson(res, 200, { answer });
  } catch (error: any) {
    return sendJson(res, 500, {
      error: 'unexpected_server_error',
      message: error?.message ?? 'Erro interno inesperado.',
    });
  }
}
