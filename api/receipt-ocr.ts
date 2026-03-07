type OcrResult = {
  success: boolean;
  rawText?: string;
  amount?: number | null;
  date?: string | null;
  store?: string | null;
  error?: string;
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function normalizeText(input: string): string {
  return input
    .replace(/[０-９]/g, (s) => String.fromCharCode(s.charCodeAt(0) - 0xfee0))
    .replace(/[Ａ-Ｚａ-ｚ]/g, (s) => String.fromCharCode(s.charCodeAt(0) - 0xfee0))
    .replace(/￥/g, "¥")
    .replace(/\r/g, "")
    .trim();
}

function parseAmount(text: string): number | null {
  const normalized = normalizeText(text);

  const patterns = [
    /(?:合計|税込合計|ご請求額|お買上金額|お支払金額|総合計)\s*[:：]?\s*[¥￥]?\s*([\d,]+)/gi,
    /[¥￥]\s*([\d,]+)/g,
  ];

  const candidates: number[] = [];

  for (const pattern of patterns) {
    for (const match of normalized.matchAll(pattern)) {
      const raw = match[1]?.replace(/,/g, "");
      if (!raw) continue;
      const value = Number(raw);
      if (Number.isFinite(value) && value > 0) {
        candidates.push(value);
      }
    }
    if (candidates.length > 0) break;
  }

  if (candidates.length === 0) return null;
  return Math.max(...candidates);
}

function parseDate(text: string): string | null {
  const normalized = normalizeText(text);

  const patterns = [
    // 2026年03月07日
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,

    // 2026/03/07
    /(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/,

    // 26/03/07
    /(?<!\d)(\d{2})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})(?!\d)/,

    // 令和6年3月7日
    /令和\s*(\d{1,2}|元)\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,

    // 平成31年4月1日
    /平成\s*(\d{1,2}|元)\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,
  ];

  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (!match) continue;

    // Reiwa era
    if (pattern.source.includes("令和")) {
      const eraYear = match[1] === "元" ? 1 : Number(match[1]);
      const year = 2018 + eraYear;
      const month = Number(match[2]);
      const day = Number(match[3]);

      return `${year}-${month.toString().padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
    }

    // Heisei era
    if (pattern.source.includes("平成")) {
      const eraYear = match[1] === "元" ? 1 : Number(match[1]);
      const year = 1988 + eraYear;
      const month = Number(match[2]);
      const day = Number(match[3]);

      return `${year}-${month.toString().padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
    }

    let year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);

    if (year < 100) {
      year += 2000;
    }

    return `${year}-${month.toString().padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
  }

  return null;
}

function parseStore(text: string): string | null {
  const normalized = normalizeText(text);
  const lines = normalized
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  if (lines.length === 0) return null;

  const blacklist = [
    "領収書",
    "レシート",
    "合計",
    "小計",
    "税込",
    "税抜",
    "お預り",
    "お釣り",
    "ありがとう",
    "ありがとうございます",
  ];

  for (const line of lines.slice(0, 6)) {
    const isBlacklisted = blacklist.some((word) => line.includes(word));
    const hasDigit = /\d/.test(line);

    if (!isBlacklisted && !hasDigit && line.length >= 2) {
      return line;
    }
  }

  return lines[0] || null;
}

async function runVision(imageUrl: string, apiKey: string): Promise<string> {
  const response = await fetch(
    `https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        requests: [
          {
            image: {
              source: {
                imageUri: imageUrl,
              },
            },
            features: [
              {
                type: "DOCUMENT_TEXT_DETECTION",
              },
            ],
            imageContext: {
              languageHints: ["ja"],
            },
          },
        ],
      }),
    }
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Vision API error ${response.status}: ${body}`);
  }

  const data = await response.json();
  const text =
    data?.responses?.[0]?.fullTextAnnotation?.text ||
    data?.responses?.[0]?.textAnnotations?.[0]?.description ||
    "";

  if (!text) {
    throw new Error("OCR sem texto retornado");
  }

  return text;
}

export default {
  async fetch(request: Request): Promise<Response> {
    if (request.method !== "POST") {
      return json({ success: false, error: "Method not allowed" }, 405);
    }

    try {
      const { imageUrl } = (await request.json()) as { imageUrl?: string };

      if (!imageUrl || typeof imageUrl !== "string") {
        return json({ success: false, error: "imageUrl obrigatório" }, 400);
      }

      const apiKey = process.env.GOOGLE_VISION_API_KEY;

      if (!apiKey) {
        return json(
          { success: false, error: "GOOGLE_VISION_API_KEY não configurada" },
          500
        );
      }

      const rawText = await runVision(imageUrl, apiKey);

      const result: OcrResult = {
        success: true,
        rawText,
        amount: parseAmount(rawText),
        date: parseDate(rawText),
        store: parseStore(rawText),
      };

      return json(result, 200);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Erro inesperado no OCR";

      return json(
        {
          success: false,
          error: message,
        },
        500
      );
    }
  },
};
