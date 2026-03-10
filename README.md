# DJMagic.io

A SaaS app for KJs and DJs to manage song request queues. Audience members can search a DJ's song catalog, select songs, and request them to be played or to sing (karaoke).

**Philosophy:** If we build a great app for KJs (who have the same needs as DJs plus extras like multiple song versions), DJs will be happy too.

---

## Core Functionality

- **DJs/KJs** upload a CSV file in a defined format
- Songs are loaded into a SQLite database and made **searchable via FTS5**
- **Audience members** can:
  - Search the DJ's catalog
  - Select a song
  - Request it to be played
  - Request to sing it (karaoke)

### KJ-Specific Features

- Multiple versions of a song: acoustic, duet, key changes
- Same queue management as DJs

---

## Architecture

This monorepo contains two Rails applications and shared code:

```
djm-mono/
├── core/               # Main Rails app (UI, Hotwire, SQLite, Pico.css)
├── songs/              # Rails API-only app (song uploads, songs DB)
├── shared/djm_jwt/     # Shared JWT gem (used by both apps)
├── fixtures/csvs/      # Sample CSV files for testing
├── docs/               # Feature planning docs
├── Procfile.dev         # Foreman process definitions
├── bin/setup            # First-time setup (deps, DBs, .env)
├── bin/dev              # One-command dev startup
├── bin/stop             # Kill running dev processes
└── bin/reset            # Destroy and recreate all databases
```

### Core App

- **Stack:** Rails, Hotwire, SQLite, plain CSS
- **Responsibilities:**
  - All UI and user-facing flows
  - Authentication, sessions, user management
  - Queue management (except song data itself)
  - Everything *except* song upload files and songs database tables

### Songs App

- **Stack:** Rails API-only, SQLite
- **Responsibilities:**
  - Receiving and processing CSV uploads
  - Songs database tables
  - FTS5 full-text search over the catalog
  - Serving song/catalog data to the core app

### Shared (`shared/djm_jwt/`)

A Ruby gem used by both apps:

- **JWT generation** — core app issues JWTs scoped to a user/catalog
- **JWT validation** — songs app verifies JWTs before accepting requests
- **Algorithm:** HS256 with a shared secret (`DJM_JWT_SECRET` env var)

---

## Catalog Model & CSV Upload Flow

### Catalog Model (Core App)

The core app has a `Catalog` model that holds metadata about a DJ's song catalog. The actual song data lives in the songs app — the core app only tracks the catalog's existence and status.

### CSV Upload Flow

1. DJ initiates an upload from the core app UI
2. Core app issues a **JWT** scoped to the DJ/catalog
3. DJ uploads the CSV directly to the **songs app**, presenting the JWT
4. Songs app validates the JWT, stores the CSV via **Active Storage** (disk in dev, Tigris/S3 in prod)
5. A **background job** validates the CSV, builds a versioned SQLite+FTS5 database, and atomically swaps it in

### Per-Catalog SQLite Databases

- **One SQLite database per catalog** — each catalog gets its own versioned `.db` file with FTS5 indexes
- These databases are **artifacts generated from the CSVs**, not source-of-truth data
- They are **not replicated via LiteFS** — only the songs app's main application database uses LiteFS
- **Atomic versioning** — new DB is built as `catalog_{id}_v{version}.db`, pointer updates only when ready, old version cleaned up after
- **On startup**, each songs app instance regenerates the per-catalog databases from CSVs in Active Storage

### Storage

| What | Where (dev) | Where (prod) | Replicated? |
|------|-------------|--------------|-------------|
| CSVs (source of truth) | Local disk (Active Storage) | Tigris (S3-compatible) | By Tigris |
| Per-catalog SQLite DBs | Local disk on songs instance | Local disk on songs instance | No — regenerated on startup |
| Songs app application DB | SQLite | SQLite via LiteFS | Yes (prod) |
| Core app application DB | SQLite | SQLite via LiteFS | Yes (prod) |

### Databases

Each app uses multiple SQLite databases. In development these are all in the app's `storage/` directory.

#### Core App (`core/storage/`)

| Database | File (dev) | Purpose |
|----------|-----------|---------|
| **Primary** | `development.sqlite3` | Users, sessions, catalogs, queue state |

Production adds a `queue` database for Solid Queue.

#### Songs App (`songs/storage/`)

| Database | File (dev) | Purpose |
|----------|-----------|---------|
| **Primary** | `development.sqlite3` | Catalog records, Active Storage metadata |
| **Queue** | `development_queue.sqlite3` | Solid Queue (background job state) |
| **Active Storage blobs** | `development.sqlite3` (in primary) | File attachment metadata |
| **Per-catalog song DBs** | `catalog_{id}_v{version}.db` | FTS5-indexed song data (not managed by Rails) |

The per-catalog song databases are built by background jobs from uploaded CSVs and are not part of the Rails migration lifecycle — they are generated artifacts.

---

## CSV Format Specification

### Header Rules

- CSV **must** have a header row
- Headers are **case-insensitive** (`Title` = `title`)
- **Trimmed of whitespace**
- Column **order does not matter**

### Columns

```
title,artist,version,album,id
```

### Required Columns

1. **title** — song title
2. **artist** — performer/artist name

If either is missing → **reject the file**.

### Optional Columns

3. **version** — for KJs: Original, Acoustic, Live, Key +2, Duet, etc.
4. **album** — display-only; helpful but not required
5. **id** — optional external identifier if the DJ has one

### Rules

**Allowed:**
- Columns can appear in any order
- Extra columns are allowed but ignored
- Headers are case-insensitive
- Blank `version`, `album`, `id` fields are fine

**Rejected:**
- Missing `title` or `artist`
- Duplicate normalized headers
- Empty header cells

---

## Limits

| Resource | Limit |
|----------|-------|
| Rows per catalog | 1,000,000 |
| Catalogs per account | 100 |
| Total song rows per account | 10,000,000 |

---

## UI & Styling

- **CSS framework:** [Pico.css](https://picocss.com/) (classless version)
- **Custom CSS** only for app-specific UI (e.g. zebra-striped tables, queue management controls)
- **Theme:** auto-detect from `prefers-color-scheme`, with a user-accessible light/dark toggle
- No build step for CSS — plain CSS served directly

---

## Tech Summary

| Component | Framework | DB | UI / API | Notes |
|-----------|-----------|----|---------|-------|
| **core** | Rails 8 | SQLite | Hotwire + Pico.css (classless) | Auth, queue management, UI |
| **songs** | Rails 8 API | SQLite + FTS5 | JSON API | Active Storage, Solid Queue |
| **shared/djm_jwt** | Ruby gem | — | — | HS256 JWT signing/verification |

---

## Hosting & Infrastructure

- **Platform:** [Fly.io](https://fly.io)
- **CDN / HTTP caching:** [Cloudflare](https://www.cloudflare.com/) — handles HTTP caching (no Solid Cache)
- **SQLite replication:** [LiteFS](https://fly.io/docs/litefs/) for application databases only
- **Object storage:** [Tigris](https://www.tigrisdata.com/) (S3-compatible) for CSV files via Active Storage
- **Email:** AWS SES (production), MailHog (development)
- Each Rails app (`core`, `songs`) is deployed as a separate Fly.io app
- **GET requests must be read-only** — LiteFS may route GETs to read replicas. All state mutation must happen via POST/PATCH/PUT/DELETE, which LiteFS forwards to the primary
- LiteFS replicates the **application databases** (users, sessions, queue state, etc.)
- Per-catalog song databases are **not replicated** — they are regenerated from Active Storage CSVs on each instance startup
- CSV processing (background jobs) runs on the **songs app primary server** only via Solid Queue

### Songs App Sharding

The songs app is shardable — each shard is a separate Fly.io app (e.g. `djm-songs-1`, `djm-songs-2`) with its own volume, application database, and per-catalog SQLite DBs.

Each catalog in the core app has a `songs_shard` integer (default `1`) that determines which songs app instance handles its uploads, search, and status requests. The `Catalog#songs_app_url` method resolves the shard number to a URL via per-shard env vars, falling back to `SONGS_APP_URL` when no shard-specific var exists (e.g. in development).

### Deployment Layout

```
Fly.io
├── djm-core              # core Rails app (Hotwire UI)
│   └── LiteFS            # replicates core application DB
├── djm-songs-1           # songs shard 1
│   ├── LiteFS            # replicates songs application DB
│   ├── catalog DBs/      # per-catalog SQLite+FTS5 (local, not replicated)
│   └── background jobs   # CSV → SQLite processing (primary only)
├── djm-songs-2           # songs shard 2 (added as needed)
│   ├── LiteFS
│   ├── catalog DBs/
│   └── background jobs
└── Tigris                # S3-compatible storage for CSV files (shared)
```

---

## Development Setup

### Prerequisites

- Ruby 3.4+
- [MailHog](https://github.com/mailhog/MailHog) (for dev email, SMTP on `localhost:1025`, web UI on `localhost:8025`)
- [Foreman](https://github.com/ddollar/foreman) (`gem install foreman`)

### First-time setup

```bash
# From the monorepo root — installs deps, creates/migrates DBs, sets up .env files
bin/setup
```

This is idempotent — safe to re-run after pulling new changes to pick up new gems or migrations.

### Running the app

```bash
# From the monorepo root — starts all processes
bin/dev
```

This launches via Foreman:

| Process | Port | Description |
|---------|------|-------------|
| **core** | 3000 | Main Rails app (UI) |
| **songs** | 3001 | Songs API app |
| **songs_jobs** | — | Solid Queue worker (background jobs) |

### Stopping / cleaning up stale processes

If servers fail to start because of stale PID files or ports still in use:

```bash
bin/stop
```

This kills any running server processes, cleans up PID files, and frees ports 3000/3001.

### Starting from scratch

To destroy all databases (both apps), catalog DBs, and Active Storage uploads, then recreate empty databases:

```bash
bin/reset
```

This will prompt for confirmation before proceeding.

### Environment Variables

Both apps use `.env` files (loaded by `dotenv-rails`):

| Variable | Used by | Description |
|----------|---------|-------------|
| `DJM_JWT_SECRET` | core, songs | Shared secret for JWT signing (must match) |
| `SONGS_APP_URL` | core | Default/fallback songs app URL (`http://localhost:3001` in dev) |
| `SONGS_SHARD_N_URL` | core | Per-shard songs app URL (e.g. `SONGS_SHARD_1_URL`). Optional — falls back to `SONGS_APP_URL` |
| `CORE_APP_URL` | songs | URL of the core app (`http://localhost:3000` in dev) |

### Test fixtures

Sample CSV files for testing uploads are in `fixtures/csvs/`.

---

## Production Deployment

### Fly.io Apps

| Fly app | Source | Notes |
|---------|--------|-------|
| `djm-core` | `core/` | LiteFS for DB replication |
| `djm-songs-1` | `songs/` | Songs shard 1. LiteFS for app DB, Active Storage → Tigris for CSVs |
| `djm-songs-N` | `songs/` | Additional shards added as needed (same source, separate Fly app + volume) |

### Environment Variables (Production)

Set on each Fly.io app via `fly secrets set`:

```bash
# Both apps (set on each Fly app)
fly secrets set DJM_JWT_SECRET=<generate-a-strong-secret>

# Core app
fly secrets set SONGS_APP_URL=https://songs1.djmagic.io   # fallback default
fly secrets set SONGS_SHARD_1_URL=https://songs1.djmagic.io
# fly secrets set SONGS_SHARD_2_URL=https://songs2.djmagic.io  # when adding shards

# Songs app (set on each shard)
fly secrets set CORE_APP_URL=https://djmagic.io
```

### Active Storage

- **Development:** disk service (default)
- **Production:** S3-compatible service pointing to Tigris

### Key Constraints

- **GET requests must be read-only** — LiteFS may route GETs to read replicas
- **Background jobs** (CSV processing) run on the songs app **primary server** only
- Per-catalog song DBs are **not replicated** — rebuilt from Active Storage CSVs on instance startup

---

## Roadmap

- [x] Define CSV format for song catalog uploads
- [x] Set up `core` Rails app (Hotwire, SQLite, Pico.css)
- [x] Set up `songs` Rails API app
- [x] Implement `shared/djm_jwt` gem (JWT generation/validation)
- [x] Core ↔ Songs integration (JWT auth, CORS, env-based URLs)
- [x] Authentication (magic links, optional password, account locking)
- [x] CSV upload flow (Active Storage, background job, FTS5, atomic versioning)
- [x] Song search endpoint (FTS5, bm25 ranking, prefix matching, diacritics support)
- [x] Queue management MVP (shows, queue CRUD, standard rotation, now playing, manual overrides)
- [ ] Queue management (singer groups, fairness enforcement, traditional queue)
- [ ] Audience experience (QR code entry, search, song requests)
- [ ] Singer view (live queue position, estimated wait time)
- [ ] Live notifications (Web Push "you're up next" / "you're up!" alerts)
- [ ] Manual song entry (for KJs using streaming services)
- [ ] Song suggestions (singers suggest songs to add to the catalog)
- [ ] Request history (per-show and cross-show)
- [ ] KJ-specific: multiple song versions (acoustic, duet, key changes)

---

## Notes

- Both apps use SQLite for simplicity and portability
- FTS5 provides fast full-text search over song titles, artists, etc.
- The songs app is intentionally isolated and shardable — each shard is a separate Fly.io app with its own volume, and catalogs are assigned to shards via the `songs_shard` column
- LiteFS replicates application databases only; per-catalog song DBs are disposable artifacts
- CSVs in Active Storage are the source of truth for song data; SQLite catalog DBs are a derived cache
- On songs app instance boot, catalog DBs are regenerated from stored CSVs — no replication needed
- Deploys and scaling are simple: spin up a new instance, it rebuilds its catalog DBs automatically
- Development email is handled by MailHog (`localhost:1025` SMTP, `localhost:8025` web UI)
- Production email uses AWS SES
