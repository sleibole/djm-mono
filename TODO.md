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

## UI / UX

- [x] Make navbar collapse to a hamburger menu on small screens
- [ ] Let DJ/KJ choose display label: "Catalog" or "Songbook" (per-user setting, affects all user-facing text for the DJ/KJ and their audience; internals stay "catalog")

## Accounts & Roles

- [ ] Differentiate DJ/KJ vs. audience accounts (currently everyone can do everything; in the future, audience members should have a distinct, lighter experience — e.g. no catalog management, just search/request)

## Infrastructure / Scaling

- [ ] Shard songs app to handle Fly.io 500GB per-volume limit (one volume per instance — per-catalog SQLite DBs will eventually exceed this as user base grows)
