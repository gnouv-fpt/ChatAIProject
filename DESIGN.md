---
name: Lộ trình — Teal Clarity
source-of-truth: web/src/app.css (the :root token block)
colors:
  primary: '#0b7568'
  primary-hover: '#075c52'
  primary-soft: '#e3f5ee'
  accent: '#e68a67'
  accent-soft: '#f5b392'
  accent-strong: '#da7965'
  mint: '#b7ebd1'
  mint-strong: '#92dfbc'
  ink: '#142731'
  ink-2: '#1a3b44'
  on-ink: '#f2f7f5'
  on-ink-muted: '#93afb3'
  bg-page: '#eef3f2'
  bg-subtle: '#e4eceb'
  bg-surface: '#ffffff'
  bg-surface-hover: '#f2f9f6'
  border-light: '#e2ebe9'
  border-default: '#d2dfdd'
  border-strong: '#92b6b1'
  text-primary: '#132830'
  text-secondary: '#486066'
  text-muted: '#647b80'
  success: '#15803d'
  warning: '#b45309'
  danger: '#b91c1c'
  info: '#1d4ed8'
typography:
  family: Be Vietnam Pro (all text), system-ui fallback
  base-size: 15px
  line-height: 1.6
  minimum-ui-size: 12px (never smaller for readable text)
rounded:
  sm: 12px
  md: 18px
  lg: 24px
  full: 999px
---

## Brand & style

A calm, trustworthy study tool for Vietnamese traffic law. Teal is the single brand color (actions, active states, links). Coral (`--accent`) is a small secondary highlight, never a second primary. Mint is reserved for highlights on dark surfaces (active sidebar item, 3D studio controls). Dark "ink" surfaces are used only for the sidebar, the sign-in hero and the 3D studio.

The earlier khaki/yellow "CSGT" themes and the Indigo spec are retired. Do not reintroduce yellow (`#facc15`, `#eab308`, `#8f5600`, …).

## Rules

- **Tokens only.** Use `var(--…)` from `web/src/app.css`. Add a token before adding a new color. Legacy names (`--csgt-primary`, `--csgt-gold`, …) are aliases kept for compatibility — prefer `--primary`, `--accent`.
- **One global stylesheet.** `web/src/app.css` is the only global CSS. Feature styles live next to their feature (`src/features/**.css`). Do not add new "theme" files that override earlier ones; change the token or the rule instead.
- **No `!important`** except reduced-motion and the two cases commented in `app.css`.
- **Responsive helpers.** `.desktop-only` hides at ≤768px. On mobile the topbar shows brand, "Làm đề nhanh" and the avatar; navigation moves to the bottom bar.
- **Topbar** holds only: search (goes to Văn bản with `?q=`), "Làm đề nhanh", AI quota (only when the API returns it), user chip. No status chips or marketing badges.
- **Sidebar** holds only navigation and the user footer. No promo cards or nav badges.
- **Data states.** Counts, percentages, pass thresholds and charts come from the selected bank, exam or progress API. Show `—` or a clear empty state until data arrives; never fill a metric with a sample number.
- Buttons and inputs: 40–44px tall, `--radius-sm`, focus ring `3px var(--primary-soft)` + primary border.
- Cards: white surface, 1px `--border-light`, `--radius-md`, `--shadow-sm`.
- The exam iframe page (`Presentation/wwwroot/exams/index.html`) is standalone; its `:root` copies these token values literally — keep them in sync.
