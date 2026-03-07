# CSV Format Guide

This guide explains how to format your CSV file for uploading a song catalog to DJMagic.io.

---

## Quick Start

Your CSV needs at minimum two columns: **title** and **artist**. That's it — upload and you're ready to go.

```
title,artist
Bohemian Rhapsody,Queen
Hotel California,Eagles
```

---

## Columns

| Column | Required? | Description |
|--------|-----------|-------------|
| **title** | Yes | The song title |
| **artist** | Yes | The performer or artist name |
| **version** | No | Song version — useful for karaoke: Original, Acoustic, Duet, Key +2, etc. |
| **album** | No | Album name (display only) |
| **id** | No | Your own external identifier, if you have one |

### Example with all columns

```
title,artist,version,album,id
Bohemian Rhapsody,Queen,Original,A Night at the Opera,SC-1001
Bohemian Rhapsody,Queen,Key -2,A Night at the Opera,SC-1002
Don't Stop Believin',Journey,Duet,Escape,SC-1003
Sweet Caroline,Neil Diamond,Acoustic,,SC-1004
```

---

## Header Rules

- Your CSV **must** have a header row as the first line
- Headers are **case-insensitive** — `Title`, `TITLE`, and `title` all work
- Leading and trailing whitespace is trimmed automatically
- Columns can appear in **any order**
- Extra columns beyond the five listed above are allowed but will be ignored

---

## What Will Be Rejected

Your file will fail validation if:

- **Missing required columns** — both `title` and `artist` must be present in the header
- **Blank title or artist** — every row must have a non-empty title and artist
- **Duplicate headers** — e.g. two columns both named `title` (after case normalization)
- **Empty header cells** — a header cell that is blank or whitespace-only

If validation fails, you'll see specific error messages explaining what went wrong and which rows have issues.

---

## Optional Columns

Blank values in optional columns are perfectly fine:

```
title,artist,version,album,id
Yesterday,The Beatles,,,
Imagine,John Lennon,Original,Imagine,
```

---

## KJ Tips: Using the Version Column

If you're a karaoke host, the **version** column lets you offer multiple versions of the same song so singers can pick the right one:

```
title,artist,version
Don't Stop Believin',Journey,Original
Don't Stop Believin',Journey,Key -2
Don't Stop Believin',Journey,Duet
Total Eclipse of the Heart,Bonnie Tyler,Original
Total Eclipse of the Heart,Bonnie Tyler,Acoustic
Total Eclipse of the Heart,Bonnie Tyler,Key +3
```

Common version labels: Original, Acoustic, Live, Duet, Key +1, Key -1, Key +2, Key -2, Explicit, Clean.

---

## Limits

| Resource | Limit |
|----------|-------|
| Maximum file size | 100 MB |
| Maximum rows per catalog | 1,000,000 |
| Maximum catalogs per account | 100 |
| Maximum total rows across all catalogs | 10,000,000 |

---

## Uploading

When you upload a new CSV to an existing catalog, it **replaces** the entire catalog. The previous version stays active while the new one is being processed, so there's no downtime — your audience can keep searching and requesting songs while the update happens in the background.
