# Zine Maker

Mini photo-zine maker for migsousa.com, served from GitHub Pages at
https://ms-runs.github.io/zine-maker/ and embedded in Squarespace with an iframe
(`squarespace-embed.html`).

- `index.html` — the tool (vanilla JS, jsPDF + supabase-js from CDN, no build step)
- `supabase-setup.sql` — run once in the Supabase SQL editor
- `scripts/expire-zines.mjs` + `.github/workflows/expire-zines.yml` — hourly cleanup

Temporary saves: each visitor (anonymous, per browser) keeps up to 3 zines, each deleted
24 hours after its first save. Limits are enforced in the database.

Repository secrets needed (Settings → Secrets and variables → Actions):
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. The service-role / secret key must never
appear in any page file — only the publishable key belongs in `index.html`.
