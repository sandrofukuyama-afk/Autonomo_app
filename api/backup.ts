import { gzipSync } from 'zlib';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const CRON_SECRET = process.env.CRON_SECRET;
const BACKUP_BUCKET = process.env.BACKUP_BUCKET || 'system_backups';
const BACKUP_RETENTION_DAYS = Number(process.env.BACKUP_RETENTION_DAYS || '30');

type AnyRow = Record<string, unknown>;

type BackupPayload = {
  generated_at: string;
  generated_by: 'vercel-cron' | 'manual';
  company_id: string;
  tables: {
    app_settings: AnyRow[];
    entries_v2: AnyRow[];
    expenses_v2: AnyRow[];
    expense_receipts: AnyRow[];
    monthly_fiscal_snapshots: AnyRow[];
  };
  counts: {
    app_settings: number;
    entries_v2: number;
    expenses_v2: number;
    expense_receipts: number;
    monthly_fiscal_snapshots: number;
  };
};

function jsonResponse(res: any, status: number, body: Record<string, unknown>) {
  return res.status(status).json(body);
}

function getAdminClient(): SupabaseClient {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Missing SUPABASE_URL/NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  }

  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

function isAuthorized(req: any): boolean {
  if (!CRON_SECRET) {
    return true;
  }

  const authHeader = typeof req.headers?.authorization === 'string'
    ? req.headers.authorization
    : '';

  if (authHeader === `Bearer ${CRON_SECRET}`) {
    return true;
  }

  if (typeof req.query?.secret === 'string' && req.query.secret === CRON_SECRET) {
    return true;
  }

  if (typeof req.body?.secret === 'string' && req.body.secret === CRON_SECRET) {
    return true;
  }

  return false;
}

function isCronRequest(req: any): boolean {
  return req.headers?.['x-vercel-cron'] === '1';
}

function sanitizeTimestampForFileName(iso: string): string {
  return iso.replace(/[:.]/g, '-');
}

function buildBackupPath(companyId: string, generatedAt: string): string {
  const safeTimestamp = sanitizeTimestampForFileName(generatedAt);
  return `${companyId}/backups/backup_${safeTimestamp}.json.gz`;
}

function daysBetween(now: Date, then: Date): number {
  return (now.getTime() - then.getTime()) / (1000 * 60 * 60 * 24);
}

async function ensureBucketExists(client: SupabaseClient): Promise<void> {
  const { data: buckets, error: listError } = await client.storage.listBuckets();
  if (listError) {
    throw new Error(`Failed to list storage buckets: ${listError.message}`);
  }

  const exists = (buckets || []).some((bucket) => bucket.name === BACKUP_BUCKET);
  if (exists) {
    return;
  }

  const { error: createError } = await client.storage.createBucket(BACKUP_BUCKET, {
    public: false,
    fileSizeLimit: '100MB',
  });

  if (createError && !createError.message.toLowerCase().includes('already exists')) {
    throw new Error(`Failed to create bucket ${BACKUP_BUCKET}: ${createError.message}`);
  }
}

async function fetchAllRows(
  client: SupabaseClient,
  table: string,
  companyId: string,
  orderColumn = 'id',
): Promise<AnyRow[]> {
  const pageSize = 1000;
  let from = 0;
  const rows: AnyRow[] = [];

  while (true) {
    const to = from + pageSize - 1;

    const query = client
      .from(table)
      .select('*')
      .eq('company_id', companyId)
      .order(orderColumn, { ascending: true })
      .range(from, to);

    const { data, error } = await query;

    if (error) {
      throw new Error(`Failed to fetch ${table}: ${error.message}`);
    }

    const batch = (data || []).map((row) => ({ ...(row as AnyRow) }));
    rows.push(...batch);

    if (batch.length < pageSize) {
      break;
    }

    from += pageSize;
  }

  return rows;
}

async function fetchAppSettings(client: SupabaseClient, companyId: string): Promise<AnyRow[]> {
  const { data, error } = await client
    .from('app_settings')
    .select('*')
    .eq('company_id', companyId);

  if (error) {
    throw new Error(`Failed to fetch app_settings: ${error.message}`);
  }

  return (data || []).map((row) => ({ ...(row as AnyRow) }));
}

async function buildCompanyBackupPayload(
  client: SupabaseClient,
  companyId: string,
  generatedBy: 'vercel-cron' | 'manual',
  generatedAt: string,
): Promise<BackupPayload> {
  const [appSettings, entries, expenses, receipts, snapshots] = await Promise.all([
    fetchAppSettings(client, companyId),
    fetchAllRows(client, 'entries_v2', companyId, 'entry_date'),
    fetchAllRows(client, 'expenses_v2', companyId, 'expense_date'),
    fetchAllRows(client, 'expense_receipts', companyId, 'uploaded_at'),
    fetchAllRows(client, 'monthly_fiscal_snapshots', companyId, 'fiscal_month'),
  ]);

  return {
    generated_at: generatedAt,
    generated_by: generatedBy,
    company_id: companyId,
    tables: {
      app_settings: appSettings,
      entries_v2: entries,
      expenses_v2: expenses,
      expense_receipts: receipts,
      monthly_fiscal_snapshots: snapshots,
    },
    counts: {
      app_settings: appSettings.length,
      entries_v2: entries.length,
      expenses_v2: expenses.length,
      expense_receipts: receipts.length,
      monthly_fiscal_snapshots: snapshots.length,
    },
  };
}

async function uploadBackup(
  client: SupabaseClient,
  companyId: string,
  payload: BackupPayload,
): Promise<{ path: string; signedUrl: string | null; sizeBytes: number }> {
  const json = JSON.stringify(payload, null, 2);
  const gzipped = gzipSync(Buffer.from(json, 'utf-8'));
  const path = buildBackupPath(companyId, payload.generated_at);

  const { error: uploadError } = await client.storage
    .from(BACKUP_BUCKET)
    .upload(path, gzipped, {
      upsert: true,
      contentType: 'application/gzip',
    });

  if (uploadError) {
    throw new Error(`Failed to upload backup for ${companyId}: ${uploadError.message}`);
  }

  const { data: signedData, error: signedError } = await client.storage
    .from(BACKUP_BUCKET)
    .createSignedUrl(path, 60 * 60 * 24 * 7);

  if (signedError) {
    return {
      path,
      signedUrl: null,
      sizeBytes: gzipped.byteLength,
    };
  }

  return {
    path,
    signedUrl: signedData?.signedUrl || null,
    sizeBytes: gzipped.byteLength,
  };
}

async function pruneOldBackups(client: SupabaseClient, companyId: string): Promise<number> {
  const folder = `${companyId}/backups`;
  const { data, error } = await client.storage
    .from(BACKUP_BUCKET)
    .list(folder, {
      limit: 1000,
      offset: 0,
      sortBy: { column: 'name', order: 'desc' },
    });

  if (error) {
    throw new Error(`Failed to list backups for ${companyId}: ${error.message}`);
  }

  const now = new Date();
  const filesToDelete: string[] = [];

  for (const file of data || []) {
    const createdAtRaw =
      typeof file.created_at === 'string' ? file.created_at : null;

    const createdAt = createdAtRaw ? new Date(createdAtRaw) : null;
    if (!createdAt || Number.isNaN(createdAt.getTime())) {
      continue;
    }

    if (daysBetween(now, createdAt) > BACKUP_RETENTION_DAYS) {
      filesToDelete.push(`${folder}/${file.name}`);
    }
  }

  if (filesToDelete.length === 0) {
    return 0;
  }

  const { error: removeError } = await client.storage
    .from(BACKUP_BUCKET)
    .remove(filesToDelete);

  if (removeError) {
    throw new Error(`Failed to prune old backups for ${companyId}: ${removeError.message}`);
  }

  return filesToDelete.length;
}

async function listCompanyIds(client: SupabaseClient): Promise<string[]> {
  const { data, error } = await client
    .from('companies')
    .select('id')
    .order('created_at', { ascending: true });

  if (error) {
    throw new Error(`Failed to load companies: ${error.message}`);
  }

  return (data || [])
    .map((row) => String((row as { id?: string }).id || '').trim())
    .filter(Boolean);
}

function extractRequestedCompanyIds(req: any): string[] {
  const rawQueryCompanyId = typeof req.query?.company_id === 'string'
    ? req.query.company_id
    : null;

  const rawBodyCompanyId = typeof req.body?.company_id === 'string'
    ? req.body.company_id
    : null;

  const rawBodyCompanyIds = Array.isArray(req.body?.company_ids)
    ? req.body.company_ids
    : null;

  const ids = new Set<string>();

  if (rawQueryCompanyId) ids.add(rawQueryCompanyId.trim());
  if (rawBodyCompanyId) ids.add(rawBodyCompanyId.trim());

  if (rawBodyCompanyIds) {
    for (const item of rawBodyCompanyIds) {
      if (typeof item === 'string' && item.trim()) {
        ids.add(item.trim());
      }
    }
  }

  return Array.from(ids).filter(Boolean);
}

export default async function handler(req: any, res: any) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return jsonResponse(res, 405, {
      error: 'method_not_allowed',
      message: 'Use GET or POST.',
    });
  }

  if (!isAuthorized(req)) {
    return jsonResponse(res, 401, {
      error: 'unauthorized',
      message: 'Invalid or missing authorization.',
    });
  }

  try {
    const client = getAdminClient();
    await ensureBucketExists(client);

    const generatedAt = new Date().toISOString();
    const generatedBy = isCronRequest(req) ? 'vercel-cron' : 'manual';

    const requestedCompanyIds = extractRequestedCompanyIds(req);
    const companyIds = requestedCompanyIds.length > 0
      ? requestedCompanyIds
      : await listCompanyIds(client);

    if (companyIds.length === 0) {
      return jsonResponse(res, 200, {
        ok: true,
        message: 'No companies found to back up.',
        companies_processed: 0,
        backups: [],
      });
    }

    const results: Array<Record<string, unknown>> = [];

    for (const companyId of companyIds) {
      const payload = await buildCompanyBackupPayload(
        client,
        companyId,
        generatedBy,
        generatedAt,
      );

      const upload = await uploadBackup(client, companyId, payload);
      const prunedFiles = await pruneOldBackups(client, companyId);

      results.push({
        company_id: companyId,
        backup_path: upload.path,
        backup_url: upload.signedUrl,
        size_bytes: upload.sizeBytes,
        pruned_files: prunedFiles,
        counts: payload.counts,
      });
    }

    return jsonResponse(res, 200, {
      ok: true,
      generated_at: generatedAt,
      generated_by: generatedBy,
      bucket: BACKUP_BUCKET,
      retention_days: BACKUP_RETENTION_DAYS,
      companies_processed: results.length,
      backups: results,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Unexpected backup error';

    return jsonResponse(res, 500, {
      ok: false,
      error: 'backup_failed',
      message,
    });
  }
}
