// Hourly cleanup: deletes zines past their 24-hour window, their photos,
// and anonymous visitor identities older than 3 days.
// Runs in GitHub Actions with the service-role key (bypasses RLS) — never ship this key to the browser.
import { createClient } from '@supabase/supabase-js';

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});
const BUCKET = 'zine-photos';

const { data: expired, error } = await sb.from('zines')
  .select('id, owner').lt('expires_at', new Date().toISOString());
if (error) throw error;

for (const z of expired) {
  const prefix = `${z.owner}/${z.id}`;
  const { data: files } = await sb.storage.from(BUCKET).list(prefix, { limit: 100 });
  if (files?.length) {
    const { error: rmErr } = await sb.storage.from(BUCKET).remove(files.map(f => `${prefix}/${f.name}`));
    if (rmErr) { console.error(`photos for ${z.id}:`, rmErr.message); continue; }  // retry next hour
  }
  await sb.from('zines').delete().eq('id', z.id);
}
console.log(`Expired ${expired.length} zine(s).`);

// Old anonymous identities (their zines are long gone by now).
const cutoff = Date.now() - 3 * 24 * 3.6e6;
let page = 1, removed = 0;
for (;;) {
  const { data, error: listErr } = await sb.auth.admin.listUsers({ page, perPage: 1000 });
  if (listErr) throw listErr;
  for (const u of data.users) {
    if (u.is_anonymous && new Date(u.created_at).getTime() < cutoff) {
      await sb.auth.admin.deleteUser(u.id);
      removed++;
    }
  }
  if (data.users.length < 1000) break;
  page++;
}
console.log(`Removed ${removed} old anonymous visitor(s).`);
