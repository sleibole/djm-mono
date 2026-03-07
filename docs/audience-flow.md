# Audience Flow

## Overview

The audience experience is designed to be zero-friction. A singer walks into a venue, scans a QR code, and immediately lands on the KJ's catalog page — no app download, no account creation, no signup form. From there they can search the catalog, submit a request, and track their position in the queue in real time.

---

## QR Code Entry

Each KJ gets a unique URL for their active show. The KJ prints or displays a QR code that links to it.

**How it works:**

1. KJ starts a show → gets a unique show URL (e.g. `djmagic.io/s/abc123`)
2. QR code is generated for this URL (printable, displayable on a screen)
3. Singer scans the QR code with their phone camera
4. Opens directly in the mobile browser — no app, no download
5. Singer lands on the KJ's catalog page, ready to search and request

**Design goals:**

- No account required to browse the catalog or submit a request
- No app install — pure mobile web
- QR code should be easy to print (table tents, flyers) or display on a TV/monitor
- URL should also be manually typeable as a fallback

---

## Singer Journey

1. **Scan QR code** → lands on the KJ's show page
2. **Search the catalog** → find a song by title, artist, or version
3. **Submit a request** → enters their name, song goes into the rotation
4. **Track position** → personal singer view shows where they are in the queue
5. **Get notified** → push alert when they're up next, and again when it's time to sing
6. **Sing** → KJ marks the song as played
7. **Request again** → submit another song, rejoin the rotation

---

## Song Search (Audience-Facing)

- Singer searches the KJ's catalog by title, artist, or version
- Uses the same FTS5 search endpoint as the DJ-facing search
- Search is fast, prefix-matched, diacritics-insensitive
- Results show title, artist, and version (if applicable)
- No login required to search

---

## Manual Song Entry

Not every KJ uses a CSV catalog. Some use streaming services (YouTube, Karafun, etc.) and don't have a fixed song list. For these KJs, singers can manually type a song title and artist.

**How it works:**

- If the KJ enables manual entry, the search page shows a "Can't find your song?" option
- Singer types the song title (and optionally the artist)
- The request enters the queue just like a catalog search result
- The KJ sees it as a manual entry and handles it however they prefer

**When a KJ has a catalog:**

- Manual entry can still be enabled alongside catalog search
- Useful for when a singer wants a song the KJ might have but isn't in the uploaded CSV

---

## Song Suggestions

Singers can suggest songs that aren't in the KJ's catalog. This is distinct from manual entry — a suggestion is "please add this to your catalog," not "play this tonight."

**How it works:**

- Singer searches the catalog, doesn't find their song
- Option to "Suggest this song" with title and artist
- KJ sees suggestions in a separate list (not in the queue)
- KJ can optionally add suggested songs to their catalog for future shows

**Why this matters:**

- Helps KJs grow their catalog based on actual demand
- Singers feel heard even when their song isn't available tonight

---

## Singer View

Every singer who submits a request gets a personal status page showing their position in the queue.

**What it shows:**

- Current position in the rotation (e.g. "You're #7")
- Estimated wait time (based on average song length and queue depth)
- Status updates: "waiting," "up next," "you're up!", "done"
- Their request history for the current show

**Design goals:**

- Reduces "am I next?" interruptions to the KJ
- Updates live (via WebSocket or polling)
- Works without an account — tied to the singer's session for this show

---

## Live Notifications

Push-style alerts keep singers informed without them having to stare at their phone or pester the KJ.

**Notification triggers:**

- **"You're up next!"** — sent when the singer moves to the on-deck position
- **"You're up!"** — sent when it's their turn to sing

**Implementation options:**

- Web Push API (works without an app install, but requires notification permission)
- Fallback: in-page alerts with audio cue for singers who have the page open
- The singer view page itself updates live regardless

**Design goals:**

- Reduce no-shows (singer wandered off, didn't hear their name called)
- Reduce KJ stress (no more shouting names across the room)
- Permission prompt should be friendly and explain the benefit, not aggressive

---

## Request History

Singers can see what they've sung during the current show.

**For singers:**

- List of songs they've sung tonight (title, artist, time)
- Available on their singer view page

**For KJs:**

- Full show history: who sang what, when, in what order
- Useful for tracking regulars, avoiding repeats, and post-show review
- Persisted beyond the show for long-term analytics

---

## No-Account Experience

The core audience experience works without any account:

- Scan QR code → search → request → track position → get notified → sing
- All tied to a browser session, no email or signup required

Optional account (via magic link) unlocks:

- Cross-show request history ("songs I've sung")
- Favorite songs
- Personal stats

---

## Design Decisions

- [ ] How do we identify a singer across requests within a show? (Session cookie? Name they enter?)
- [ ] Do we require a name for each request, or once per show?
- [ ] How do we handle duplicate names? (Two "Mike"s in the queue)
- [ ] Can a singer have multiple songs in the queue at once?
- [ ] How does the KJ enable/disable manual song entry?
- [ ] How does the KJ enable/disable song suggestions?
- [ ] What's the notification permission UX? When do we prompt?
