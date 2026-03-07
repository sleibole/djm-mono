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
- [ ] Audience-facing search UI in core app

## UI / UX

- [x] Make navbar collapse to a hamburger menu on small screens
