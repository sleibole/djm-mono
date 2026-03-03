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
├── core/          # Main Rails app (UI, Hotwire, SQLite, plain CSS)
├── songs/         # Rails API-only app (song uploads, songs DB)
└── shared/        # Shared utilities (JWT generation/validation)
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

### Shared Directory

- **Responsibilities:**
  - JWT generation (core app issues these)
  - JWT validation (songs app validates them)
- **Auth flow:** When a user needs to talk to the songs app, they receive a JWT from the core app. The songs app validates the JWT before serving data.

---

## Catalog Model & CSV Upload Flow

### Catalog Model (Core App)

The core app has a `Catalog` model that holds metadata about a DJ's song catalog. The actual song data lives in the songs app — the core app only tracks the catalog's existence and status.

### CSV Upload Flow

1. DJ initiates an upload from the core app UI
2. Core app issues a **JWT** scoped to the DJ/catalog
3. DJ uploads the CSV directly to the **songs app**, presenting the JWT
4. Songs app validates the JWT, stores the CSV in **Tigris** (S3-compatible object storage)
5. A **background job on the songs app primary server** processes the CSV and generates a new SQLite database for that catalog

### Per-Catalog SQLite Databases

- **One SQLite database per catalog** — each catalog gets its own `.db` file with FTS5 indexes
- These databases are **artifacts generated from the CSVs**, not source-of-truth data
- They are **not replicated via LiteFS** — only the songs app's main application database uses LiteFS
- **On startup**, each songs app instance regenerates the per-catalog databases from the CSVs stored in Tigris
- This keeps the architecture simple: CSVs in Tigris are the source of truth; SQLite databases are a derived, disposable cache

### Storage

| What | Where | Replicated? |
|------|-------|-------------|
| CSVs (source of truth) | Tigris (S3-compatible) | By Tigris |
| Per-catalog SQLite DBs | Local disk on songs instances | No — regenerated on startup |
| Songs app application DB | SQLite via LiteFS | Yes |
| Core app application DB | SQLite via LiteFS | Yes |

---

## CSV Format Specification

### Headers

- CSV **must** have a header row
- Headers are **case-insensitive** (`Title` = `title`)
- **Trimmed of whitespace**
- Column **order does not matter**

### Headers

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

## Tech Summary

| Component | Framework | DB | UI / API |
|-----------|-----------|----|---------|
| **core** | Rails | SQLite | Hotwire + plain CSS |
| **songs** | Rails API | SQLite | JSON API |
| **shared** | Ruby gem or lib | — | — |

---

## Hosting & Infrastructure

- **Platform:** [Fly.io](https://fly.io)
- **SQLite replication:** [LiteFS](https://fly.io/docs/litefs/) for application databases only
- **Object storage:** [Tigris](https://www.tigrisdata.com/) (S3-compatible) for CSV files
- Each Rails app (`core`, `songs`) is deployed as a separate Fly.io app
- LiteFS replicates the **application databases** (users, sessions, queue state, etc.)
- Per-catalog song databases are **not replicated** — they are regenerated from CSVs on each instance startup
- CSV processing (background jobs) runs on the **songs app primary server** only

### Deployment Layout

```
Fly.io
├── djm-core              # core Rails app (Hotwire UI)
│   └── LiteFS            # replicates core application DB
├── djm-songs             # songs Rails API app
│   ├── LiteFS            # replicates songs application DB
│   ├── catalog DBs/      # per-catalog SQLite+FTS5 (local, not replicated)
│   └── background jobs   # CSV → SQLite processing (primary only)
└── Tigris                # S3-compatible storage for CSV files
```

---

## Roadmap

- [x] Define CSV format for song catalog uploads
- [ ] Set up `core` Rails app (Hotwire, SQLite, plain CSS)
- [ ] Set up `songs` Rails API app
- [ ] Implement `shared` JWT generation/validation
- [ ] Implement CSV import → SQLite + FTS5 in songs app
- [ ] Core ↔ Songs integration (JWT auth, API calls)
- [ ] Queue management UI in core
- [ ] Audience-facing search/request flow
- [ ] KJ-specific: multiple song versions (acoustic, duet, key changes)

---

## Notes

- Both apps use SQLite for simplicity and portability
- FTS5 provides fast full-text search over song titles, artists, etc.
- The songs app is intentionally isolated to keep the catalog/upload logic contained and to allow for potential scaling or extraction later
- LiteFS replicates application databases only; per-catalog song DBs are disposable artifacts
- CSVs in Tigris are the source of truth for song data; SQLite catalog DBs are a derived cache
- On songs app instance boot, catalog DBs are regenerated from Tigris CSVs — no replication needed
- This means deploys and scaling are simple: spin up a new instance, it rebuilds its catalog DBs automatically
