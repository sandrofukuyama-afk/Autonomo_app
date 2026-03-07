import PDFDocument from 'pdfkit';

type EntryRow = {
  id?: string | number;
  date?: string | null;
  description?: string | null;
  category?: string | null;
  amount?: number | string | null;
  payment_method?: string | null;
};

type ExpenseRow = {
  id?: string | number;
  date?: string | null;
  description?: string | null;
  category?: string | null;
  amount?: number | string | null;
  tax?: number | string | null;
  tax_type?: string | null;
  receipt_url?: string | null;
};

type ReportBody = {
  year?: number;
  reportMode?: string;
};

const SUPABASE_URL = 'https://dzazwpgjncowkudkdhca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6YXp3cGdqbmNvd2t1ZGtkaGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MDIyODAsImV4cCI6MjA4ODM3ODI4MH0.mQBxjBlgPQpxb5-QyFNhgitM_WOnWlkEzFStYZPr5Pk';
const A4 = { width: 595.28, height: 841.89 };
const PAGE_MARGIN = 40;
const CONTENT_WIDTH = A4.width - PAGE_MARGIN * 2;
const ROW_HEIGHT = 22;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function formatYen(value: number): string {
  const safe = Number.isFinite(value) ? Math.round(value) : 0;
  return `¥ ${safe.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}

function formatDate(value: string | null | undefined): string {
  if (!value) return '-';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return String(value).split('T')[0] ?? '-';
  const yyyy = parsed.getFullYear();
  const mm = `${parsed.getMonth() + 1}`.padStart(2, '0');
  const dd = `${parsed.getDate()}`.padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function monthKey(value: string | null | undefined): string {
  if (!value) return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  return `${parsed.getFullYear()}-${`${parsed.getMonth() + 1}`.padStart(2, '0')}`;
}

function toInt(value: unknown): number {
  if (typeof value === 'number') return Number.isFinite(value) ? Math.round(value) : 0;
  if (typeof value === 'string') {
    const parsed = Number(value.replace(/,/g, '').trim());
    return Number.isFinite(parsed) ? Math.round(parsed) : 0;
  }
  return 0;
}

function sanitizeText(value: unknown, fallback = '-'): string {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
}

function normalizeTaxType(value: unknown): string {
  if (typeof value !== 'string') return '';
  if (value == 'tax_included') return '税込';
  if (value == 'tax_excluded') return '税抜';
  if (value == '税込' || value == '税抜') return value;
  return '';
}

async function fetchSupabaseRows<T>(table: string, year: number): Promise<T[]> {
  const start = `${year}-01-01`;
  const end = `${year}-12-31`;
  const url = `${SUPABASE_URL}/rest/v1/${table}?select=*&date=gte.${encodeURIComponent(start)}&date=lte.${encodeURIComponent(end)}&order=date.asc`;

  const response = await fetch(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Falha ao buscar ${table}: ${response.status} ${await response.text()}`);
  }

  return (await response.json()) as T[];
}

function pageHeader(doc: PDFKit.PDFDocument, title: string, year: number, pageNumber: number) {
  doc
    .fontSize(10)
    .fillColor('#111827')
    .text('Autonomo App — Relatório Fiscal Anual', PAGE_MARGIN, 20, { width: CONTENT_WIDTH / 2 });

  doc
    .fontSize(9)
    .fillColor('#4B5563')
    .text(`Ano fiscal: ${year}`, PAGE_MARGIN + CONTENT_WIDTH / 2, 20, { width: CONTENT_WIDTH / 2, align: 'right' });

  doc
    .moveTo(PAGE_MARGIN, 34)
    .lineTo(A4.width - PAGE_MARGIN, 34)
    .strokeColor('#D1D5DB')
    .stroke();

  doc
    .fontSize(16)
    .fillColor('#111827')
    .text(title, PAGE_MARGIN, 48, { width: CONTENT_WIDTH });

  doc
    .fontSize(9)
    .fillColor('#6B7280')
    .text(`Página ${pageNumber}`, PAGE_MARGIN + CONTENT_WIDTH - 80, A4.height - 24, { width: 80, align: 'right' });
}

function ensurePage(doc: PDFKit.PDFDocument, currentY: number, neededHeight: number, title: string, year: number, pageState: { page: number }): number {
  if (currentY + neededHeight <= A4.height - 50) {
    return currentY;
  }
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, title, year, pageState.page);
  return 80;
}

function drawSimpleTable(
  doc: PDFKit.PDFDocument,
  title: string,
  year: number,
  pageState: { page: number },
  headers: { label: string; width: number; align?: 'left' | 'right' | 'center' }[],
  rows: string[][],
  startY = 80,
) {
  let y = startY;

  const drawHeader = () => {
    doc.rect(PAGE_MARGIN, y, CONTENT_WIDTH, ROW_HEIGHT).fill('#F3F4F6');
    let x = PAGE_MARGIN;
    doc.fillColor('#111827').fontSize(9).font('Helvetica-Bold');
    for (let i = 0; i < headers.length; i += 1) {
      const header = headers[i];
      doc.text(header.label, x + 4, y + 6, {
        width: header.width - 8,
        align: header.align ?? 'left',
      });
      x += header.width;
    }
    y += ROW_HEIGHT;
    doc.font('Helvetica').fontSize(9).fillColor('#111827');
  };

  drawHeader();

  for (const row of rows) {
    y = ensurePage(doc, y, ROW_HEIGHT + 4, title, year, pageState);
    if (y === 80) {
      drawHeader();
    }

    doc.moveTo(PAGE_MARGIN, y).lineTo(A4.width - PAGE_MARGIN, y).strokeColor('#E5E7EB').stroke();
    let x = PAGE_MARGIN;
    for (let i = 0; i < headers.length; i += 1) {
      const header = headers[i];
      doc.text(row[i] ?? '', x + 4, y + 6, {
        width: header.width - 8,
        align: header.align ?? 'left',
      });
      x += header.width;
    }
    y += ROW_HEIGHT;
  }

  doc.moveTo(PAGE_MARGIN, y).lineTo(A4.width - PAGE_MARGIN, y).strokeColor('#E5E7EB').stroke();
  return y + 16;
}

async function fetchReceiptBuffer(url: string): Promise<Uint8Array | null> {
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    const arrayBuffer = await response.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  } catch {
    return null;
  }
}

async function buildPdf(entries: EntryRow[], expenses: ExpenseRow[], year: number): Promise<Uint8Array> {
  const doc = new PDFDocument({ size: 'A4', margin: PAGE_MARGIN });
  const chunks: Uint8Array[] = [];
  const pageState = { page: 1 };

  doc.on('data', (chunk: Uint8Array) => chunks.push(chunk));

  const endPromise = new Promise<Uint8Array>((resolve) => {
    doc.on('end', () => {
      const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
      const result = new Uint8Array(totalLength);
      let offset = 0;
      for (const chunk of chunks) {
        result.set(chunk, offset);
        offset += chunk.length;
      }
      resolve(result);
    });
  });

  const totalEntries = entries.reduce((sum, item) => sum + toInt(item.amount), 0);
  const totalExpenses = expenses.reduce((sum, item) => sum + toInt(item.amount), 0);
  const totalTax = expenses.reduce((sum, item) => sum + toInt(item.tax), 0);
  const netProfit = totalEntries - totalExpenses;
  const receiptsCount = expenses.filter((item) => sanitizeText(item.receipt_url, '').length > 0).length;
  const noReceiptCount = expenses.length - receiptsCount;

  const months = Array.from({ length: 12 }).map((_, index) => {
    const month = index + 1;
    const key = `${year}-${`${month}`.padStart(2, '0')}`;
    const income = entries
      .filter((item) => monthKey(item.date) === key)
      .reduce((sum, item) => sum + toInt(item.amount), 0);
    const expense = expenses
      .filter((item) => monthKey(item.date) === key)
      .reduce((sum, item) => sum + toInt(item.amount), 0);

    return {
      label: `${month.toString().padStart(2, '0')}/${year}`,
      income,
      expense,
      profit: income - expense,
    };
  });

  const expensesByCategoryMap = new Map<string, { total: number; count: number }>();
  for (const expense of expenses) {
    const category = sanitizeText(expense.category, 'Outros');
    const current = expensesByCategoryMap.get(category) ?? { total: 0, count: 0 };
    current.total += toInt(expense.amount);
    current.count += 1;
    expensesByCategoryMap.set(category, current);
  }

  const expensesByCategory = Array.from(expensesByCategoryMap.entries())
    .map(([category, data]) => ({ category, ...data }))
    .sort((a, b) => b.total - a.total);

  // Capa
  doc.font('Helvetica-Bold').fontSize(22).fillColor('#111827').text('Autonomo App', PAGE_MARGIN, 120, {
    width: CONTENT_WIDTH,
    align: 'center',
  });
  doc.fontSize(18).text('Relatório Fiscal Anual', PAGE_MARGIN, 160, {
    width: CONTENT_WIDTH,
    align: 'center',
  });
  doc.font('Helvetica').fontSize(12).fillColor('#4B5563').text(`Ano fiscal: ${year}`, PAGE_MARGIN, 210, {
    width: CONTENT_WIDTH,
    align: 'center',
  });

  doc.roundedRect(PAGE_MARGIN, 280, CONTENT_WIDTH, 130, 12).fillAndStroke('#F9FAFB', '#E5E7EB');
  doc.fillColor('#111827').font('Helvetica-Bold').fontSize(12);
  doc.text('Resumo rápido', PAGE_MARGIN + 20, 300);
  doc.font('Helvetica').fontSize(11);
  doc.text(`Receita total: ${formatYen(totalEntries)}`, PAGE_MARGIN + 20, 330);
  doc.text(`Despesa total: ${formatYen(totalExpenses)}`, PAGE_MARGIN + 20, 352);
  doc.text(`Lucro líquido: ${formatYen(netProfit)}`, PAGE_MARGIN + 20, 374);
  doc.text(`Recibos anexados: ${receiptsCount}`, PAGE_MARGIN + 320, 330);
  doc.text(`Sem recibo: ${noReceiptCount}`, PAGE_MARGIN + 320, 352);
  doc.text(`Imposto detectado: ${formatYen(totalTax)}`, PAGE_MARGIN + 320, 374);
  doc.fontSize(10).fillColor('#6B7280').text(`Gerado em ${new Date().toISOString().replace('T', ' ').slice(0, 16)}`, PAGE_MARGIN, 760, {
    width: CONTENT_WIDTH,
    align: 'center',
  });

  // Resumo anual
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Resumo Fiscal Anual', year, pageState.page);
  drawSimpleTable(
    doc,
    'Resumo Fiscal Anual',
    year,
    pageState,
    [
      { label: 'Item', width: 320 },
      { label: 'Valor', width: 195.28, align: 'right' },
    ],
    [
      ['Receita Bruta Total', formatYen(totalEntries)],
      ['Total de Despesas', formatYen(totalExpenses)],
      ['Lucro Líquido', formatYen(netProfit)],
      ['Total de Imposto Detectado', formatYen(totalTax)],
      ['Total de Receitas Lançadas', String(entries.length)],
      ['Total de Despesas Lançadas', String(expenses.length)],
      ['Total de Recibos Anexados', String(receiptsCount)],
      ['Total de Despesas sem Recibo', String(noReceiptCount)],
    ],
  );

  // Demonstrativo mensal
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Demonstrativo Mensal', year, pageState.page);
  drawSimpleTable(
    doc,
    'Demonstrativo Mensal',
    year,
    pageState,
    [
      { label: 'Mês', width: 120 },
      { label: 'Receitas', width: 140, align: 'right' },
      { label: 'Despesas', width: 140, align: 'right' },
      { label: 'Lucro', width: 155.28, align: 'right' },
    ],
    [
      ...months.map((month) => [month.label, formatYen(month.income), formatYen(month.expense), formatYen(month.profit)]),
      ['TOTAL', formatYen(totalEntries), formatYen(totalExpenses), formatYen(netProfit)],
    ],
  );

  // Receitas detalhadas
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Receitas Detalhadas', year, pageState.page);
  drawSimpleTable(
    doc,
    'Receitas Detalhadas',
    year,
    pageState,
    [
      { label: 'Data', width: 90 },
      { label: 'Descrição', width: 220 },
      { label: 'Categoria', width: 120 },
      { label: 'Valor', width: 125.28, align: 'right' },
    ],
    entries.length > 0
      ? entries.map((item) => [
          formatDate(item.date),
          sanitizeText(item.description, 'Sem descrição'),
          sanitizeText(item.category, '-'),
          formatYen(toInt(item.amount)),
        ])
      : [['-', 'Nenhuma receita encontrada no período', '-', formatYen(0)]],
  );

  // Despesas por categoria
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Despesas por Categoria', year, pageState.page);
  drawSimpleTable(
    doc,
    'Despesas por Categoria',
    year,
    pageState,
    [
      { label: 'Categoria', width: 260 },
      { label: 'Quantidade', width: 110, align: 'right' },
      { label: 'Total', width: 200.28, align: 'right' },
    ],
    expensesByCategory.length > 0
      ? expensesByCategory.map((item) => [item.category, String(item.count), formatYen(item.total)])
      : [['Outros', '0', formatYen(0)]],
  );

  // Despesas detalhadas
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Despesas Detalhadas', year, pageState.page);
  drawSimpleTable(
    doc,
    'Despesas Detalhadas',
    year,
    pageState,
    [
      { label: 'Data', width: 70 },
      { label: 'Loja/Descrição', width: 190 },
      { label: 'Categoria', width: 90 },
      { label: 'Valor', width: 80, align: 'right' },
      { label: 'Imposto', width: 70, align: 'right' },
      { label: 'Tipo', width: 45 },
      { label: 'Recibo', width: 50, align: 'center' },
    ],
    expenses.length > 0
      ? expenses.map((item) => [
          formatDate(item.date),
          sanitizeText(item.description, 'Sem descrição'),
          sanitizeText(item.category, 'Outros'),
          formatYen(toInt(item.amount)),
          toInt(item.tax) > 0 ? formatYen(toInt(item.tax)) : '',
          normalizeTaxType(item.tax_type),
          sanitizeText(item.receipt_url, '').length > 0 ? 'Sim' : 'Não',
        ])
      : [['-', 'Nenhuma despesa encontrada no período', '-', formatYen(0), '', '', 'Não']],
  );

  // Observações
  doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
  pageState.page += 1;
  pageHeader(doc, 'Observações de Conferência', year, pageState.page);
  let y = 100;
  doc.font('Helvetica').fontSize(11).fillColor('#111827');
  const warnings: string[] = [];
  if (noReceiptCount > 0) warnings.push(`${noReceiptCount} despesa(s) sem recibo anexado.`);
  const noTaxCount = expenses.filter((item) => toInt(item.tax) <= 0).length;
  if (noTaxCount > 0) warnings.push(`${noTaxCount} despesa(s) sem imposto identificado.`);
  const noCategoryCount = expenses.filter((item) => sanitizeText(item.category, '') === '').length;
  if (noCategoryCount > 0) warnings.push(`${noCategoryCount} despesa(s) sem categoria original.`);
  if (warnings.length === 0) warnings.push('Nenhuma inconsistência relevante foi identificada nos registros do período.');
  for (const warning of warnings) {
    doc.circle(PAGE_MARGIN + 4, y + 8, 2).fill('#111827');
    doc.fillColor('#111827').text(warning, PAGE_MARGIN + 14, y, { width: CONTENT_WIDTH - 14 });
    y += 24;
  }

  // Anexos de recibos
  const receiptExpenses = expenses.filter((item) => sanitizeText(item.receipt_url, '').length > 0);
  if (receiptExpenses.length > 0) {
    doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
    pageState.page += 1;
    pageHeader(doc, 'Anexos de Recibos', year, pageState.page);

    let attachmentY = 90;
    for (let index = 0; index < receiptExpenses.length; index += 1) {
      const expense = receiptExpenses[index];
      if (attachmentY > 420) {
        doc.addPage({ size: 'A4', margin: PAGE_MARGIN });
        pageState.page += 1;
        pageHeader(doc, 'Anexos de Recibos', year, pageState.page);
        attachmentY = 90;
      }

      const top = attachmentY;
      doc.roundedRect(PAGE_MARGIN, top, CONTENT_WIDTH, 320, 10).strokeColor('#D1D5DB').stroke();
      const ref = `EXP-${String(index + 1).padStart(4, '0')}`;
      doc.font('Helvetica-Bold').fontSize(10).fillColor('#111827');
      doc.text(ref, PAGE_MARGIN + 12, top + 12);
      doc.font('Helvetica').fontSize(9);
      doc.text(`Data: ${formatDate(expense.date)}`, PAGE_MARGIN + 12, top + 30);
      doc.text(`Descrição: ${sanitizeText(expense.description, 'Sem descrição')}`, PAGE_MARGIN + 12, top + 46, { width: 260 });
      doc.text(`Categoria: ${sanitizeText(expense.category, 'Outros')}`, PAGE_MARGIN + 12, top + 62, { width: 220 });
      doc.text(`Valor: ${formatYen(toInt(expense.amount))}`, PAGE_MARGIN + 300, top + 30, { width: 140 });
      doc.text(`Imposto: ${toInt(expense.tax) > 0 ? formatYen(toInt(expense.tax)) : '-'}`, PAGE_MARGIN + 300, top + 46, { width: 140 });
      doc.text(`Tipo: ${normalizeTaxType(expense.tax_type) || '-'}`, PAGE_MARGIN + 300, top + 62, { width: 140 });

      const receiptData = await fetchReceiptBuffer(String(expense.receipt_url));
      if (receiptData) {
        try {
          doc.image(receiptData, PAGE_MARGIN + 12, top + 90, {
            fit: [CONTENT_WIDTH - 24, 210],
            align: 'center',
            valign: 'center',
          });
        } catch {
          doc.font('Helvetica').fontSize(10).fillColor('#6B7280').text('Recibo não disponível para anexação', PAGE_MARGIN + 12, top + 160, {
            width: CONTENT_WIDTH - 24,
            align: 'center',
          });
        }
      } else {
        doc.font('Helvetica').fontSize(10).fillColor('#6B7280').text('Recibo não disponível para anexação', PAGE_MARGIN + 12, top + 160, {
          width: CONTENT_WIDTH - 24,
          align: 'center',
        });
      }

      attachmentY += 340;
    }
  }

  doc.end();
  return endPromise;
}

export default {
  async fetch(request: Request): Promise<Response> {
    if (request.method !== 'POST') {
      return json({ success: false, error: 'Method not allowed' }, 405);
    }

    try {
      const body = (await request.json()) as ReportBody;
      const year = Number(body.year);
      const reportMode = String(body.reportMode ?? '');

      if (!Number.isInteger(year) || year < 2000 || year > 2100) {
        return json({ success: false, error: 'Ano inválido.' }, 400);
      }

      if (reportMode !== 'complete') {
        return json({ success: false, error: 'Modo de relatório inválido.' }, 400);
      }

      const [entries, expenses] = await Promise.all([
        fetchSupabaseRows<EntryRow>('entries', year),
        fetchSupabaseRows<ExpenseRow>('expenses', year),
      ]);

      if (entries.length === 0 && expenses.length === 0) {
        return json({ success: false, error: 'Nenhum dado fiscal encontrado para o ano selecionado.' }, 404);
      }

      const pdf = await buildPdf(entries, expenses, year);
      const fileName = `autonomo_fiscal_${year}.pdf`;

      return new Response(pdf, {
        status: 200,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition': `inline; filename="${fileName}"`,
          'cache-control': 'no-store',
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro interno ao gerar PDF.';
      return json({ success: false, error: message }, 500);
    }
  },
};
