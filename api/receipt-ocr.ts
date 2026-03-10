type OcrResult = {
  success: boolean;
  rawText?: string;
  amount?: number | null;
  date?: string | null;
  store?: string | null;
  tax?: number | null;
  taxType?: "tax_included" | "tax_excluded" | "unknown";
  suggestedCategory?: string | null;
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

function buildIsoDate(year: number, month: number, day: number): string | null {
  if (
    !Number.isFinite(year) ||
    !Number.isFinite(month) ||
    !Number.isFinite(day) ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31
  ) {
    return null;
  }

  return `${year.toString().padStart(4, "0")}-${month
    .toString()
    .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
}

function parseAmount(text: string): number | null {
  const normalized = normalizeText(text);

  const priorityPatterns = [
    /(?:^|\n|\s)合計\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
    /(?:^|\n|\s)税込合計\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
    /(?:^|\n|\s)お買上金額\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
    /(?:^|\n|\s)ご請求額\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
    /(?:^|\n|\s)総合計\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
    /(?:^|\n|\s)現計\s*[:：]?\s*[¥￥]?\s*([\d,]+)/i,
  ];

  for (const pattern of priorityPatterns) {
    const match = normalized.match(pattern);
    if (match?.[1]) {
      const value = Number(match[1].replace(/,/g, ""));
      if (Number.isFinite(value) && value > 0) {
        return value;
      }
    }
  }

  const yenMatches = [...normalized.matchAll(/[¥￥]\s*([\d,]+)/g)];
  if (yenMatches.length > 0) {
    const values = yenMatches
      .map((m) => Number((m[1] ?? "").replace(/,/g, "")))
      .filter((v) => Number.isFinite(v) && v > 0);

    if (values.length > 0) {
      return Math.max(...values);
    }
  }

  const numberMatches = [
    ...normalized.matchAll(/(?:^|[^\d])(\d{1,3}(?:,\d{3})+|\d{3,})(?!\d)/g),
  ];
  if (numberMatches.length > 0) {
    const values = numberMatches
      .map((m) => Number((m[1] ?? "").replace(/,/g, "")))
      .filter((v) => Number.isFinite(v) && v > 0);

    if (values.length > 0) {
      return Math.max(...values);
    }
  }

  return null;
}

function parseDate(text: string): string | null {
  const normalized = normalizeText(text);

  const patterns = [
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,
    /(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})/,
    /(?:^|[^\d])(\d{2})[\/\-.](\d{1,2})[\/\-.](\d{1,2})(?!\d)/,
    /令和\s*(\d{1,2}|元)\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,
    /平成\s*(\d{1,2}|元)\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?/,
  ];

  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (!match) continue;

    if (pattern.source.includes("令和")) {
      const eraYear = match[1] === "元" ? 1 : Number(match[1]);
      const year = 2018 + eraYear;
      const month = Number(match[2]);
      const day = Number(match[3]);
      return buildIsoDate(year, month, day);
    }

    if (pattern.source.includes("平成")) {
      const eraYear = match[1] === "元" ? 1 : Number(match[1]);
      const year = 1988 + eraYear;
      const month = Number(match[2]);
      const day = Number(match[3]);
      return buildIsoDate(year, month, day);
    }

    let year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);

    if (year < 100) {
      year += 2000;
    }

    return buildIsoDate(year, month, day);
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
    "消費税",
    "税額",
  ];

  for (const line of lines.slice(0, 8)) {
    const isBlacklisted = blacklist.some((word) => line.includes(word));
    const hasDigit = /\d/.test(line);

    if (!isBlacklisted && !hasDigit && line.length >= 2) {
      return line;
    }
  }

  return lines[0] || null;
}

function parseTax(
  text: string
): {
  tax: number | null;
  taxType: "tax_included" | "tax_excluded" | "unknown";
} {
  const normalized = normalizeText(text);

  let taxType: "tax_included" | "tax_excluded" | "unknown" = "unknown";

  if (/(?:税込|内税|税[込含]|\(内税\))/i.test(normalized)) {
    taxType = "tax_included";
  } else if (/(?:税抜|外税|\(外税\)|税別)/i.test(normalized)) {
    taxType = "tax_excluded";
  }

  const taxPatterns = [
    /(?:消費税|税額|内消費税等|内税|外税)\s*[:：]?\s*[¥￥]?\s*([\d,]+)/gi,
    /10%\s*対象.*?[¥￥]?\s*([\d,]+).*?(?:消費税|税)\s*[¥￥]?\s*([\d,]+)/gi,
    /8%\s*対象.*?[¥￥]?\s*([\d,]+).*?(?:消費税|税)\s*[¥￥]?\s*([\d,]+)/gi,
  ];

  const candidates: number[] = [];

  for (const pattern of taxPatterns) {
    for (const match of normalized.matchAll(pattern)) {
      const raw = match[2]?.replace(/,/g, "") ?? match[1]?.replace(/,/g, "");
      if (!raw) continue;

      const value = Number(raw);
      if (Number.isFinite(value) && value >= 0) {
        candidates.push(value);
      }
    }
  }

  return {
    tax: candidates.length > 0 ? Math.max(...candidates) : null,
    taxType,
  };
}

function suggestCategory(text: string, store: string | null): string | null {
  const normalized = normalizeText(text).toLowerCase();
  const storeNormalized = (store ?? "").toLowerCase();

  const hasAny = (values: string[]) =>
    values.some(
      (value) => normalized.includes(value) || storeNormalized.includes(value)
    );

  if (
    hasAny([
      "7-eleven",
      "seven eleven",
      "lawson",
      "familymart",
      "mini stop",
      "ministop",
      "beisia",
      "trial",
      "aeon",
      "maxvalu",
      "maruetsu",
      "seiyu",
      "donki",
      "don quijote",
      "ベイシア",
      "ローソン",
      "ファミリーマート",
      "セブン",
      "イオン",
      "スーパー",
      "食品",
    ])
  ) {
    return "category_food";
  }

  if (
    hasAny([
      "eneos",
      "cosmo",
      "idemitsu",
      "apollostation",
      "shell",
      "出光",
      "ガソリン",
      "燃料",
      "高速",
      "駐車",
      "parking",
      "park",
      "jr",
      "suica",
      "pasmo",
      "タクシー",
      "電車",
      "駅",
    ])
  ) {
    return "category_transport";
  }

  if (
    hasAny([
      "hospital",
      "clinic",
      "pharmacy",
      "drug",
      "welcia",
      "sundrug",
      "matsukiyo",
      "マツキヨ",
      "病院",
      "医院",
      "クリニック",
      "薬局",
      "ドラッグ",
    ])
  ) {
    return "category_health";
  }

  if (
    hasAny([
      "cinema",
      "movie",
      "netflix",
      "spotify",
      "カラオケ",
      "映画",
      "ゲーム",
      "bookoff",
      "tsutaya",
    ])
  ) {
    return "category_entertainment";
  }

  return null;
}

function isValidHttpUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch (_) {
    return false;
  }
}

async function callVision(
  imageUrl: string,
  apiKey: string,
  featureType: "DOCUMENT_TEXT_DETECTION" | "TEXT_DETECTION"
): Promise<string> {
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
                type: featureType,
              },
            ],
            imageContext: {
              languageHints: ["ja", "en"],
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

  return typeof text === "string" ? text.trim() : "";
}

async function runVision(imageUrl: string, apiKey: string): Promise<string> {
  const documentText = await callVision(
    imageUrl,
    apiKey,
    "DOCUMENT_TEXT_DETECTION"
  );

  if (documentText) {
    return documentText;
  }

  const fallbackText = await callVision(imageUrl, apiKey, "TEXT_DETECTION");

  if (!fallbackText) {
    throw new Error("OCR sem texto retornado");
  }

  return fallbackText;
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

      if (!isValidHttpUrl(imageUrl)) {
        return json({ success: false, error: "imageUrl inválido" }, 400);
      }

      const apiKey = process.env.GOOGLE_VISION_API_KEY;

      if (!apiKey) {
        return json(
          { success: false, error: "GOOGLE_VISION_API_KEY não configurada" },
          500
        );
      }

      const rawText = await runVision(imageUrl, apiKey);
      const store = parseStore(rawText);
      const taxInfo = parseTax(rawText);

      const result: OcrResult = {
        success: true,
        rawText,
        amount: parseAmount(rawText),
        date: parseDate(rawText),
        store,
        tax: taxInfo.tax,
        taxType: taxInfo.taxType,
        suggestedCategory: suggestCategory(rawText, store),
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
