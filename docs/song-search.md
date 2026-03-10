# Song Search

## Overview

Song search is powered by SQLite FTS5 full-text search. Each catalog gets its own SQLite database with an FTS5 virtual table, enabling fast, typo-tolerant search across song titles, artists, and versions.

---

## FTS5 Configuration

```sql
CREATE VIRTUAL TABLE songs_fts USING fts5(
  title,
  artist,
  version,
  content=songs,
  content_rowid=id,
  tokenize="unicode61 remove_diacritics 2",
  prefix='2 3'
)
```

### Tokenizer: `unicode61 remove_diacritics 2`

- Unicode-aware tokenization (handles international characters correctly)
- `remove_diacritics 2` — most aggressive setting: "Beyonce" matches "Beyoncé", "cafe" matches "café"
- Case-insensitive by default

### Prefix Indexes: `prefix='2 3'`

- Pre-builds index entries for all 2-character and 3-character token prefixes
- Enables fast prefix queries for search-as-you-type (e.g. "boh" → instant results)
- Trade-off: slightly larger DB size (negligible for song catalogs)

---

## Search Behavior

### Prefix Matching

Every search term gets a `*` suffix automatically. The user doesn't need to type the full word:

- "bohem rhap" → `bohem* rhap*` → matches "Bohemian Rhapsody"
- "qu" → `qu*` → matches "Queen"

### Ranking: bm25

Results are ranked using FTS5's `bm25()` function with column weights:

| Column | Weight | Rationale |
|--------|--------|-----------|
| title | 10.0 | Title matches are most relevant |
| artist | 5.0 | Artist matches are important but secondary |
| version | 1.0 | Version matches are least important |

### Query Sanitization

User input is sanitized before reaching FTS5:

- FTS5 metacharacters are stripped: `" * + - ( ) ^ : { } ~ | @`
- FTS5 keywords are filtered: `AND`, `OR`, `NOT`, `NEAR`
- Terms are capped at 20 to prevent abuse
- Empty queries return no results

---

## Shard Routing

Search requests are routed to the songs app shard that owns the catalog. Each catalog has a `songs_shard` integer, and `Catalog#songs_app_url` resolves it to the correct shard URL. In development, all shards fall back to `SONGS_APP_URL` (localhost:3001).

---

## Search Endpoint

`GET /catalogs/:catalog_id/search` (on the catalog's assigned shard)

### Parameters

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `q` | Yes | — | Search query |
| `limit` | No | 25 | Results per page (max 100) |
| `offset` | No | 0 | Pagination offset |

### Response

```json
{
  "catalog_id": 1,
  "query": "bohemian",
  "total": 3,
  "songs": [
    {
      "id": 42,
      "title": "Bohemian Rhapsody",
      "artist": "Queen",
      "version": "Original",
      "album": "A Night at the Opera",
      "external_id": "1001",
      "title_highlighted": "<mark>Bohemian</mark> Rhapsody",
      "artist_highlighted": "Queen",
      "version_highlighted": "Original"
    }
  ]
}
```

### Error Responses

| Status | Condition |
|--------|-----------|
| 400 | Missing `q` parameter |
| 404 | Catalog not found |
| 422 | Catalog exists but is not ready (still processing or failed) |

---

## Audience-Facing Search

The audience search experience (accessed via QR code) uses the same endpoint but is served from a public page in the core app — no login required. See [Audience Flow](audience-flow.md) for details.

---

## Design Decisions

- [ ] Should we add album to the FTS5 index? (Currently not indexed, display only)
- [ ] Do we need pagination UI, or is a single page of results sufficient for most queries?
- [ ] Should we log popular search queries for KJ analytics?
