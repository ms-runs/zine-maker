# CLAUDE.md — Zine Maker

Context for Claude Code. Read this before changing anything.

## What this is
A web tool for creating and sharing mini one-page photo zines, for Miguel's photography
portfolio at migsousa.com (Squarespace). Served from GitHub Pages
(https://ms-runs.github.io/zine-maker/, repo `ms-runs/zine-maker`) and embedded in
Squarespace via the iframe in `squarespace-embed.html`.

Long-term goal: a small creative publishing tool where Miguel and a few trusted editors can
compose, save and share zines, while anyone can view the gallery.

## Files
- `index.html` — the whole tool: vanilla JS, jsPDF + supabase-js from CDN. **No build step** — keep it that way.
- `supabase-setup.sql` — schema, RLS policies and limit triggers; run once in the Supabase SQL editor.
- `scripts/expire-zines.mjs` + `.github/workflows/expire-zines.yml` — hourly cleanup of expired zines, photos and old anonymous users (Node 22, service-role key from repo secrets).
- `squarespace-embed.html` — iframe snippet for a Squarespace Code Block.

## Zine format (get this right)
- One printed sheet (US Letter or A4, user's choice), printed double-sided, 8 panels per side.
- Built as two accordion strips joined by glue tabs.
  - Side A: glue tab, pages 9–12, front cover, back cover, glue tab.
  - Side B: pages 1–8.
- The cut separating the two strips does **not** go all the way across — it stops short at both
  ends, leaving uncut hinges that fold over 180° and glue flat onto the adjoining row. Any
  assembly instructions or fold diagrams must reflect this exactly.
- Autofill reading order: front cover → pages 1–12 → back cover.
- Horizontal photos rotate to fit a portrait cell by default, or can span 2 adjacent cells.
  Portrait photos can get an optional white border (starts at 2% of cell width).
- Text: only the front cover takes text boxes (`zine.coverTexts`, saved in `layout.coverTexts`).
  Each box stores centre (cx, cy), width (w) and size as fractions of the cover panel, plus font
  (Helvetica / Futura / Bodoni / Times New Roman, with Jost / Bodoni Moda / Tinos Google Fonts
  fallbacks), alignment and one of 12 palette colours. PDF export and the gallery thumbnail
  draw the text on canvas with the same font stacks and wrapping as the editor.
- Metadata: title, date, description.

## Shipped features
Photo tray with drag-and-drop into cells; per-cell pan/zoom/rotate/border/span; autofill;
cell-to-cell swap via drag handle; cover title text (drag to move, handles to resize, font/size/align/centre/colour, arrow-key nudge); in-app confirm dialog; re-center button; gallery landing
grid (cover per zine → per-photo gallery view → PDF download); runtime host-theme detection;
all CSS scoped under `#zm-app`.

## Storage
- Local: two-tier localStorage — lightweight gallery index + one key per zine's full data.
- Cloud (temporary saves, Supabase): each browser gets an anonymous identity (no sign-up);
  max 3 zines per visitor, each deleted 24h after first save; limits enforced by DB triggers
  (plus a 60-zine site-wide cap). Photos downscaled to JPEG ≤2 MB in the private
  `zine-photos` bucket under `<owner>/<zine id>/`. The UI warns visitors about these limits.
- Only the **publishable** key belongs in `index.html`. The service-role key lives only in
  GitHub Actions secrets (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) — never commit it.

## Hard-won rules
- Embedded contexts block `window.confirm()`/`alert()` — always use custom in-app dialogs.
- Storage writes can fail silently — show success only after a confirmed write.
- Never keep all zines in a single localStorage key (size limits) — index and payload separate.
- Scope all CSS; nothing may leak into the host page.
- Site theme: white background, near-black text, mid-grey body text, muted slate-blue accent.

## Next up
Shared storage for a small group of trusted editors (Supabase auth + RLS) who can create and
edit permanent zines, while anyone can view the public gallery.

## Related (not in this repo)
`zine-assembly-instructions.pdf` — IKEA-style illustrated assembly manual (generated with
wkhtmltopdf), with the corrected hinge steps.
