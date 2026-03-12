# TODO

Tracked improvements, enhancements, and ideas.

## Catalogs & Uploads

- [ ] Show catalog processing status on the catalogs index page (so users can see status even if they navigate away from the catalog show page after uploading)
- [x] Create CSV format documentation page and link to it from the upload form
- [ ] Consider an alerts/notifications system — e.g. user uploads a large file, navigates away, comes back later and gets notified that processing finished (or failed)
- [x] Fix error display bug — status endpoint returns errors as objects, UI joins them as `[object Object]`
- [ ] Enforce row/catalog limits (1M rows per catalog, 100 catalogs per account, 10M total rows per account)
- [ ] Regenerate per-catalog SQLite DBs from Active Storage CSVs on songs app startup

## Song Search

- [x] Build song search endpoint on songs app (query FTS5 catalog databases)
- [ ] Audience-facing search UI in core app (public, no login required)
- [x] DJ-facing search + song count on catalog show page

## Audience Experience

- [ ] QR code entry — generate per-show QR codes that link to the KJ's catalog page (no app, no account)
- [ ] Singer view — personal "where am I in line?" page with live position updates
- [ ] Manual song entry — singers can type any song title (for KJs using streaming services or missing catalog entries)
- [ ] Song suggestions — singers can suggest songs not in the catalog for the KJ to add later
- [ ] Live notifications — "You're up next!" and "You're up!" push alerts via Web Push API (with in-page fallback)
- [ ] Request history — singers see what they've sung tonight; KJs see full show history

## Queue Management

- [x] Show model (KJ starts/ends shows, queue belongs to a show)
- [x] Show type (karaoke/dj) with contextual display labels ("Singer" vs "Guest"/"Requester")
- [x] Participant model (per-DJ, lightweight temporary records, optional account linking)
- [x] Queue CRUD (add, remove, reorder)
- [x] Standard rotation (new participants go to bottom, KJ works top to bottom)
- [x] "Now playing" state
- [x] KJ manual overrides (bump, skip, remove)
- [x] Add to queue via catalog search OR manual song entry
- [x] Participant autocomplete (from DJ's previous shows)
- [x] Max songs per participant (KJ-configurable per show)
- [ ] Traditional queue rotation style
- [ ] Participant groups (keep friends contiguous in the queue)
- [ ] Fairness enforcement (no repeats, no line-cutting)
- [ ] Cleanup stale participant records (auto-delete after 2 weeks of inactivity)

## Shows

- [ ] Allow DJs to toggle "require approval" during show creation (currently only configurable via show settings after creation)
- [ ] Allow creating shows ahead of time (scheduled, not yet live)
- [ ] Allow naming shows (currently uses catalog name as the display title)
- [ ] Rich text event description for audience-facing show pages (ActionText?)

## UI / UX

- [x] Make navbar collapse to a hamburger menu on small screens
- [ ] Let DJ/KJ choose display label: "Catalog" or "Songbook" (per-user setting, affects all user-facing text for the DJ/KJ and their audience; internals stay "catalog")

## Accounts & Roles

- [ ] Differentiate DJ/KJ vs. audience accounts (currently everyone can do everything; in the future, audience members should have a distinct, lighter experience — e.g. no catalog management, just search/request)

## Infrastructure / Scaling

- [x] Shard songs app — each catalog has a `songs_shard` integer that routes requests to the correct songs app instance (e.g. `songs1.djmagic.io`). Per-shard URLs configured via `SONGS_SHARD_N_URL` env vars, falling back to `SONGS_APP_URL`
- [ ] Admin tooling to reassign catalogs between shards
