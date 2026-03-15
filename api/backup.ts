import { createClient } from '@supabase/supabase-js'
import { gzipSync } from 'zlib'

const SUPABASE_URL = process.env.SUPABASE_URL!
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY!
const CRON_SECRET = process.env.CRON_SECRET!
const BUCKET = process.env.BACKUP_BUCKET || 'system_backups'
const RETENTION_DAYS = Number(process.env.BACKUP_RETENTION_DAYS || 30)

export default async function handler(req: any, res: any) {

  if (req.query.secret !== CRON_SECRET) {
    return res.status(401).json({ error: 'unauthorized' })
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE)

  try {

    // garantir bucket
    const { data: buckets } = await supabase.storage.listBuckets()

    const exists = buckets?.find(b => b.name === BUCKET)

    if (!exists) {
      await supabase.storage.createBucket(BUCKET, {
        public: false
      })
    }

    // buscar empresas
    const { data: companies } = await supabase
      .from('companies')
      .select('id')

    const results: any[] = []

    for (const company of companies || []) {

      const company_id = company.id

      const [entries, expenses, receipts, settings, snapshots] =
        await Promise.all([
          supabase.from('entries_v2').select('*').eq('company_id', company_id),
          supabase.from('expenses_v2').select('*').eq('company_id', company_id),
          supabase.from('expense_receipts').select('*').eq('company_id', company_id),
          supabase.from('app_settings').select('*').eq('company_id', company_id),
          supabase.from('monthly_fiscal_snapshots').select('*').eq('company_id', company_id)
        ])

      const payload = {
        generated_at: new Date().toISOString(),
        company_id,
        entries_v2: entries.data,
        expenses_v2: expenses.data,
        expense_receipts: receipts.data,
        app_settings: settings.data,
        monthly_fiscal_snapshots: snapshots.data
      }

      const json = JSON.stringify(payload)
      const gz = gzipSync(Buffer.from(json))

      const filename = `${company_id}/backup_${Date.now()}.json.gz`

      await supabase.storage
        .from(BUCKET)
        .upload(filename, gz, {
          contentType: 'application/gzip',
          upsert: true
        })

      results.push({
        company_id,
        file: filename
      })

      // limpeza backups antigos
      const { data: files } = await supabase.storage
        .from(BUCKET)
        .list(`${company_id}`)

      const now = Date.now()

      for (const file of files || []) {

        const created = new Date(file.created_at).getTime()

        const diffDays = (now - created) / (1000 * 60 * 60 * 24)

        if (diffDays > RETENTION_DAYS) {
          await supabase.storage
            .from(BUCKET)
            .remove([`${company_id}/${file.name}`])
        }
      }
    }

    return res.status(200).json({
      ok: true,
      backups: results
    })

  } catch (error: any) {

    return res.status(500).json({
      ok: false,
      error: 'backup_failed',
      message: error.message
    })

  }
}
