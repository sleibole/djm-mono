# CSV Upload

## Overview

A DJ uploads a CSV file to replace their catalog. The core app authorizes the upload and issues a JWT. The DJ's browser uploads the CSV directly to the songs app, which stores it via Active Storage, enqueues a background job, and returns immediately. The background job validates the CSV, builds a versioned SQLite+FTS5 database, and atomically swaps it in.

---

## Upload Flow

```
DJ Browser                  Core App                Songs App              Active Storage
    │                          │                        │                     │
    ├── clicks "Upload" ──────>│                        │                     │
    │                          ├── creates/updates      │                     │
    │                          │   Catalog record       │                     │
    │                          ├── generates JWT        │                     │
    │<── returns JWT + ────────┤                        │                     │
    │    songs upload URL      │                        │                     │
    │                          │                        │                     │
    ├── POST CSV + JWT ────────────────────────────────>│                     │
    │                          │                        ├── validate JWT      │
    │                          │                        ├── store CSV ───────>│
    │                          │                        ├── enqueue job       │
    │<── 202 Accepted ─────────────────────────────────-┤                     │
    │                          │                        │                     │
    │                          │                        ├── (background job)  │
    │                          │                        ├── read CSV <────────┤
    │                          │                        ├── validate CSV      │
    │                          │                        ├── build SQLite DB   │
    │                          │                        │   (versioned name)  │
    │                          │                        ├── build FTS5 index  │
    │                          │                        ├── update pointer    │
    │                          │                        │                     │
    │── poll status ───────────────────────────────────>│                     │
    │<── { status: "ready" } ──────────────────────────-┤                     │
```

---

## Step-by-Step Detail

### 1. DJ Initiates Upload (Core App)

- DJ navigates to their catalog management page
- Clicks "Upload CSV" (or "Replace Catalog")
- Core app creates or updates the `Catalog` record
- Core app generates a short-lived JWT containing:
  - `catalog_id` — which catalog this upload is for
  - `user_id` — who is uploading
  - `exp` — expiration (short-lived, 5 minutes)
- Core app returns the JWT and the songs app upload endpoint URL to the browser

### 2. Browser Uploads to Songs App

- Browser sends a `POST` to the songs app with:
  - The CSV file (multipart form data)
  - The JWT in the `Authorization` header
- This is a direct browser → songs app request (the CSV never passes through the core app)

### 3. Songs App Receives Upload

- Validates the JWT (signature, expiry, claims)
- On JWT failure: returns `401 Unauthorized`
- On success:
  - Stores the CSV via **Active Storage** (disk in dev, Tigris/S3 in prod)
  - Creates or updates a `CatalogRecord` with status `pending`
  - Enqueues `BuildCatalogJob`
  - Returns `202 Accepted`

No CSV validation happens at upload time — that's the background job's responsibility.

### 4. Background Job: BuildCatalogJob

The job runs on the songs app and:

1. Downloads/reads the CSV from Active Storage
2. **Validates the CSV:**
   - Must have a header row
   - Normalize headers: downcase, strip whitespace
   - Must contain `title` and `artist` — reject if missing
   - No duplicate headers after normalization
   - No empty header cells
   - Every row must have a non-blank `title` and `artist`
   - Returns **all** header errors and up to **20 row-level errors**
3. **If invalid:** marks CatalogRecord as `failed` with structured error details
4. **If valid:**
   - Creates a new SQLite database file with a versioned name: `catalog_{id}_v{version}.db`
   - Creates the `songs` table and FTS5 virtual table
   - Inserts all rows from the CSV
   - Updates the CatalogRecord's `active_db_version` pointer to the new version
   - Cleans up the previous version's DB file
5. Marks CatalogRecord as `ready`

**Atomic swap:** The old DB continues serving search queries while the new one is being built. Only when the new DB is fully ready does the pointer update. No downtime during rebuilds.

**Idempotent:** The job can be retried safely — it always builds a new versioned DB.

### 5. Core App Polls for Status

- Core app polls the songs app status endpoint: `GET /catalogs/:catalog_id/status`
- Returns current status (`pending`, `processing`, `ready`, `failed`) and error details if failed
- UI uses Turbo to poll and update the status display

---

## Songs Table Schema

```sql
CREATE TABLE songs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  version TEXT,
  album TEXT,
  external_id TEXT
);

CREATE VIRTUAL TABLE songs_fts USING fts5(
  title,
  artist,
  version,
  content=songs,
  content_rowid=id
);
```

---

## Versioned DB Naming

| Concept | Example |
|---------|---------|
| DB file pattern | `catalog_{catalog_id}_v{version}.db` |
| First upload | `catalog_42_v1.db` |
| Second upload | `catalog_42_v2.db` (v1 cleaned up after swap) |
| Pointer | `CatalogRecord.active_db_version = 2` |

---

## File Storage

| Environment | Backend | Config |
|-------------|---------|--------|
| Development | Local disk | Active Storage disk service |
| Production | Tigris (S3-compatible) | Active Storage S3 service |

---

## Limits

| Resource | Limit |
|----------|-------|
| Max file size | 100 MB |
| Rows per catalog | 1,000,000 |
| Uploads per user per hour | 5 |

---

## Validation (in Background Job)

**Header validation:**
- Must have a header row
- Normalize headers: downcase, strip whitespace
- Must contain `title` and `artist` — reject if missing
- No duplicate headers after normalization
- No empty header cells
- Unknown columns are ignored (not an error)

**Row validation:**
- Every row must have a non-blank `title` and `artist`
- Blank `version`, `album`, `id` are fine
- Report up to 20 row-level errors

**On failure:** CatalogRecord marked as `failed` with structured errors:

```json
{
  "errors": [
    { "type": "missing_header", "detail": "Required header 'artist' is missing" },
    { "type": "blank_field", "row": 42, "column": "title", "detail": "Title is blank on row 42" }
  ]
}
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid/expired JWT | 401, DJ re-initiates upload |
| File too large | 413, rejected at upload |
| CSV validation fails | CatalogRecord marked `failed` with errors, DJ re-uploads |
| Job failure | Job retries; catalog stays on previous version |
| No previous version + failure | Catalog has no active DB, status shows error |

---

## Startup: Regenerating Catalog DBs

When a songs app instance starts (deploy, scale-out, restart):

1. List all CatalogRecords with an `active_db_version`
2. For each, download the CSV from Active Storage
3. Build the SQLite DB (same process as the background job)
4. Catalog is ready to serve searches
