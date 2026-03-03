# CSV Upload

## Overview

A DJ uploads a CSV file to replace their catalog. The core app authorizes the upload and issues a JWT. The DJ's browser uploads the CSV directly to the songs app, which validates it, stores it in Tigris, and kicks off a background job to build a per-catalog SQLite database.

---

## Upload Flow

```
DJ Browser                  Core App                Songs App              Tigris
    │                          │                        │                     │
    ├── clicks "Upload" ──────>│                        │                     │
    │                          ├── creates/updates      │                     │
    │                          │   Catalog record       │                     │
    │                          ├── generates JWT ──────>│                     │
    │<── returns JWT + ────────┤   (scoped to           │                     │
    │    songs upload URL      │    catalog)            │                     │
    │                          │                        │                     │
    ├── POST CSV + JWT ────────────────────────────────>│                     │
    │                          │                        ├── validate JWT      │
    │                          │                        ├── validate CSV      │
    │                          │                        │   (headers, format) │
    │                          │                        │                     │
    │                          │                  (if invalid)                │
    │<── 422 + errors ─────────────────────────────────-┤                     │
    │                          │                        │                     │
    │                          │                  (if valid)                  │
    │                          │                        ├── store CSV ───────>│
    │                          │                        ├── enqueue build job │
    │<── 202 Accepted ─────────────────────────────────-┤                     │
    │                          │                        │                     │
    │                          │                        ├── (background job)  │
    │                          │                        ├── download CSV <────┤
    │                          │                        ├── build SQLite DB   │
    │                          │                        ├── build FTS5 index  │
    │                          │                        ├── swap in new DB    │
    │                          │                        │                     │
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
  - `exp` — expiration (short-lived, e.g. 5 minutes)
- Core app returns the JWT and the songs app upload endpoint URL to the browser

### 2. Browser Uploads to Songs App

- Browser sends a `POST` to the songs app with:
  - The CSV file (multipart form data)
  - The JWT in the `Authorization` header
- This is a direct browser → songs app request (the CSV never passes through the core app)

### 3. Songs App Validates the JWT

- Verifies signature using the shared secret/key
- Checks `exp` — reject if expired
- Extracts `catalog_id` and `user_id`
- On failure: returns `401 Unauthorized`

### 4. Songs App Validates the CSV

Validation happens **before** storing the file. This keeps bad data out of Tigris.

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

**On failure:** return `422 Unprocessable Entity` with a structured error response:

```json
{
  "errors": [
    { "type": "missing_header", "detail": "Required header 'artist' is missing" },
    { "type": "blank_field", "row": 42, "column": "title", "detail": "Title is blank on row 42" }
  ]
}
```

**On success:** proceed to storage.

### 5. Store CSV in Tigris

- Store the validated CSV in Tigris under a predictable key:
  ```
  catalogs/{catalog_id}/catalog.csv
  ```
- Overwrite any previous CSV for this catalog (a catalog has exactly one active CSV)
- The CSV in Tigris is the **source of truth** for the catalog's song data

### 6. Enqueue Background Job

- Return `202 Accepted` to the browser immediately
- Enqueue a `BuildCatalogJob` to run on the **primary server** with `catalog_id`

### 7. Background Job: Build Catalog DB

The job runs on the songs app primary and:

1. Downloads the CSV from Tigris
2. Creates a new SQLite database file: `catalogs/{catalog_id}.db`
3. Creates the `songs` table:
   ```sql
   CREATE TABLE songs (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     title TEXT NOT NULL,
     artist TEXT NOT NULL,
     version TEXT,
     album TEXT,
     external_id TEXT
   );
   ```
4. Creates the FTS5 virtual table:
   ```sql
   CREATE VIRTUAL TABLE songs_fts USING fts5(
     title,
     artist,
     version,
     content=songs,
     content_rowid=id
   );
   ```
5. Inserts all rows from the CSV
6. Populates the FTS5 index
7. Swaps the new DB file into place (atomic rename)

**Rebuilds are idempotent** — the job can be retried safely because it builds a new DB and swaps it in.

---

## Error Handling

| Scenario | Response | Recovery |
|----------|----------|----------|
| Invalid/expired JWT | 401 | DJ re-initiates upload from core app |
| Missing required headers | 422 + errors | DJ fixes CSV and re-uploads |
| Blank required fields in rows | 422 + errors | DJ fixes CSV and re-uploads |
| Tigris write failure | 500 | Retry upload |
| Background job failure | — | Job retries automatically; catalog stays on previous version until success |

---

## Startup: Regenerating Catalog DBs

When a songs app instance starts (deploy, scale-out, restart):

1. List all known catalogs (from the songs app application DB)
2. For each catalog, download the CSV from Tigris
3. Build the SQLite DB (same process as the background job)
4. Catalog is ready to serve searches

This means per-catalog DBs are never replicated — they're rebuilt from Tigris on every instance.

---

## Open Questions

- [ ] Should we support **partial validation** (return all errors at once) or **fail-fast** (stop at first error)?
- [ ] Max file size limit for CSV uploads?
- [ ] Should the core app poll the songs app for build status, or should the songs app notify the core app (webhook/callback)?
- [ ] Do we need to keep previous CSV versions in Tigris, or is overwrite fine?
- [ ] Rate limiting on uploads?
