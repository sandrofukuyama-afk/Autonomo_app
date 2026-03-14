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

CONTEXTO DO PRODUTO
O Autonomo App é um sistema para trabalhadores autônomos no Japão.
Ele ajuda o usuário a:
- registrar entradas
- registrar despesas
- anexar recibos
- usar OCR em recibos
- revisar despesas fiscais
- fechar mês fiscal
- gerar relatório fiscal
- exportar PDF, CSV e ZIP
- trabalhar em múltiplos idiomas (PT, ES, EN, JA)

ESCOPO DAS RESPOSTAS
Você pode responder sobre:
1. uso do aplicativo
2. conceitos fiscais básicos no Japão
3. explicações simples e práticas para o usuário final

VOCÊ PODE EXPLICAR
- como cadastrar entrada
- como cadastrar despesa
- quando anexar recibo
- o que significa OCR
- o que é revisão fiscal
- o que acontece ao fechar o mês
- diferença entre 税込 e 税抜
- diferença entre despesas dedutíveis e não dedutíveis
- noções básicas de Blue Return e White Return
- noções básicas de imposto de consumo no Japão
- noções básicas de organização fiscal para autônomos no Japão

LIMITES IMPORTANTES
- não invente regras fiscais
- não forneça aconselhamento legal definitivo
- não afirme que algo é 100% permitido sem ressalva se depender de contexto contábil
- não mande o usuário alterar banco de dados, código ou configurações técnicas, a menos que ele pergunte claramente algo técnico
- não execute ações no sistema
- não diga que fechou mês, alterou despesa ou corrigiu registro
- não responda fora do contexto do app e de dúvidas fiscais básicas no Japão; se a pergunta fugir muito disso, diga educadamente que sua ajuda é focada no Autonomo App e em dúvidas fiscais básicas

ESTILO
- responda no idioma solicitado: ${language}
- seja claro, direto e útil
- prefira respostas curtas e práticas
- quando útil, use passos numerados curtos
- quando a dúvida for fiscal sensível, diga que a resposta é informativa e pode precisar de confirmação com contador no Japão

EXEMPLOS DE TOM
- "税込 significa que o imposto já está incluído no valor."
- "税抜 significa que o imposto será calculado por fora."
- "No app, o recibo deve ser anexado à despesa para melhorar a organização e a revisão fiscal."
- "Blue Return oferece vantagens fiscais, mas a elegibilidade depende da forma de escrituração."

FORMATO DE SAÍDA
- responda em texto puro
- sem markdown complexo
- sem JSON
- sem código, exceto se o usuário pedir explicitamente algo técnico
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
    final body = await readBody(req);
    final question = (body?.question ?? '').toString().trim();
    final language = (body?.language ?? 'pt').toString().trim();

    if (question.isEmpty) {
      return sendJson(res, 400, {
        error: 'missing_question',
        message: 'Pergunta não informada.',
      });
    }

    final apiResponse = await fetch('https://api.openai.com/v1/responses', {
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

    final rawText = await apiResponse.text();
    dynamic data;

    try {
      data = rawText.isNotEmpty ? JSON.parse(rawText) : {};
    } catch (_) {
      return sendJson(res, 502, {
        error: 'invalid_openai_response',
        message: 'Resposta inválida da OpenAI.',
        raw: rawText,
      });
    }

    if (!apiResponse.ok) {
      return sendJson(res, apiResponse.status, {
        error: 'openai_request_failed',
        message: data?['error']?['message'] ??
            'A OpenAI retornou erro ao processar a solicitação.',
        type: data?['error']?['type'],
        code: data?['error']?['code'],
      });
    }

    final answer =
        (data?['output_text'] ?? '').toString().trim().isNotEmpty
            ? (data['output_text'] as String).trim()
            : (((data?['output'] is List &&
                            data['output'].isNotEmpty &&
                            data['output'][0]?['content'] is List &&
                            data['output'][0]['content'].isNotEmpty)
                        ? data['output'][0]['content'][0]?['text']
                        : '') ??
                    '')
                .toString()
                .trim();

    if (answer.isEmpty) {
      return sendJson(res, 502, {
        error: 'empty_ai_answer',
        message: 'A IA não retornou texto.',
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
