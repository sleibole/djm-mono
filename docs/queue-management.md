# Queue Management

## Overview

The queue is the core of a live show. DJs and KJs manage a list of upcoming song requests. Different KJs/DJs have strong preferences about how the queue rotates — we need to support multiple rotation styles.

---

## Rotation Styles

### Standard Rotation

Singers are added to the bottom of a single list. As long as new people keep joining, the people at the top don't sing again until you cycle through everyone. When you reach the bottom, go back to the top.

**How it works:**
- New singer → goes to the bottom of the list
- KJ works top to bottom
- When the bottom is reached, wrap back to the top

**Characteristics:**
- Simple to run — no shifting names around, no waiting on songs
- Rewards latecomers — they get to sing faster (shorter wait to first turn)
- Rewards show-hoppers — arrive, sing, leave for another show
- Can feel unfair to people who arrived early and stay all night

### Traditional Queue

Works like a bank line. You sing, then get back in line when you submit a new song. Your position is based on when you re-enter the queue, not a fixed rotation slot.

**How it works:**
- New singer submits a song → goes to the back of the line
- Singer finishes → they're out of the queue
- If they want to sing again, they submit a new song and rejoin at the back
- New and returning singers are interleaved by arrival order

**Characteristics:**
- Feels fair — first come, first served, every time
- Returning singers don't get a guaranteed "next" slot
- Can cause confusion: "I was behind Bob, what happened?" (because new people entered between rotations)
- Higher wait times in large crowds (50+ singers can mean 4+ hours between turns)

---

## Singer Groups

Singers can be organized into groups (e.g. a table of friends, a party, a couple doing duets). Groups affect queue behavior in important ways.

**How it works:**
- KJ can create a group and assign singers to it
- Group members remain **contiguous** in the queue — they always stay together as a block
- If a group member drops out (leaves, goes to the bathroom, skips), the group block stays intact and closes the gap rather than leaving a hole
- If a group member returns, the KJ can slot them back into the group without disrupting the rest of the queue
- KJ can reorder within a group or reorder the group as a whole relative to other singers/groups

**Why this matters:**
- Groups of friends want to sing near each other, not scattered across a 2-hour queue
- When someone steps away (bathroom, smoke break) and misses their turn, the KJ can skip them without breaking up the group — the rest of the group still sings together
- Makes KJ reordering simpler: move one group block instead of individually repositioning 4 people

**Edge cases:**
- Singer in a group submits a second song — does it stay with the group or go to the back?
- Group member leaves permanently — remove from group, group contracts
- Can a singer belong to multiple groups? (Probably not — keep it simple)
- Can the audience self-organize into groups, or is this KJ-only?

---

## Fairness Enforcement

Both rotation styles enforce fairness automatically:

- **No repeats** — a singer can't sing again until the rotation cycles through everyone (Standard Rotation) or until they rejoin at the back (Traditional Queue)
- **No line-cutting** — position is determined by arrival order; no way to jump ahead
- **KJ overrides** — the KJ can still manually adjust (bump someone up, skip, remove) when needed, but the default behavior keeps things fair without intervention

---

## Live Notifications

Push-style alerts keep singers informed without them staring at their phone or pestering the KJ.

**Notification triggers:**

| Trigger | Message | Purpose |
|---------|---------|---------|
| On-deck | "You're up next!" | Give the singer time to get ready |
| Their turn | "You're up!" | It's time to sing |

**Implementation options:**

- **Web Push API** — works without an app install, but requires notification permission from the singer
- **In-page alerts** — fallback for singers who decline push permissions; audio cue + visual update on the singer view page
- **Singer view page** updates live regardless of push permission (via WebSocket or polling)

**Design goals:**

- Reduce no-shows (singer wandered off, didn't hear their name)
- Reduce KJ stress (no more shouting names across the room)
- Permission prompt should explain the benefit clearly, not be aggressive

---

## Request History

### For Singers

- Songs they've sung during the current show (title, artist, time)
- Available on their singer view page
- Optional account unlocks cross-show history ("songs I've sung")

### For KJs

- Full show history: who sang what, when, in what order
- Useful for tracking regulars, avoiding repeats across shows, and post-show review
- Persisted for long-term analytics

---

## Song Suggestions

Singers can suggest songs that aren't in the KJ's catalog. This is distinct from song requests — a suggestion is "please add this to your catalog for next time," not "play this tonight."

- Singer searches the catalog, doesn't find their song
- Option to "Suggest this song" with title and artist
- KJ sees suggestions in a separate list (not in the queue)
- KJ can optionally add suggested songs to their catalog for future shows
- Helps KJs grow their catalog based on actual demand

---

## Design Decisions

- [x] Which rotation styles do we support at launch? **Standard Rotation first.**
- [x] Is rotation style a per-show setting or an account-level default? **Account-level default, overridable per show.**
- [x] Can a KJ switch rotation style mid-show? **Yes.**
- [ ] How do we communicate expected wait time to singers?
- [ ] How does the UI differ between rotation styles (if at all)?
- [ ] What's the notification permission UX? When do we prompt?
- [ ] Do we store song suggestions per-catalog or per-show?
- [x] Can a singer have multiple songs in the queue at once? **KJ-configurable setting (max_songs_per_singer).**
- [x] How do we add songs to the queue? **Search the catalog OR enter manually (both supported).**
- [x] Where does the KJ manage the queue? **Standalone show page, separate from catalogs.**
- [x] Real-time updates? **Polling for now. Turbo page refresh with morph or Turbo Frames with periodic reload.**

## Participant Model

Participants (formerly "Singer") are lightweight, temporary records scoped per DJ:

- **Model name:** `Participant` (internal), displayed as "Singer" (karaoke) or "Guest"/"Requester" (DJ) based on show type
- **Scoped per DJ** via `dj_id` foreign key — each DJ has their own set of participants
- A Participant has a name and optional link to a User account (`user_id`)
- No account required to be in a queue (KJ enters the participant's name)
- Records without a linked account are automatically deleted after ~2 weeks of inactivity
- A participant can upgrade to an "audience" account to maintain history across shows
- Song history is tracked per DJ: what songs a participant has performed at which DJ's shows (via QueueEntry → Show → User)
- KJ can pick from their existing participants (autocomplete) or type a new name
- An audience member can be a participant at multiple DJs' shows (separate Participant records per DJ, unified when linked to a User account)

## Show Model

A Show represents a live performance session:

- Belongs to a Catalog and a User (the KJ)
- **Show type:** `karaoke` or `dj` — drives display labels throughout the UI
  - Karaoke: participants are called "Singers"
  - DJ: participants are called "Guests" (general) or "Requesters" (request-specific UI)
- Has a rotation style and max songs per singer setting
- Status: active or ended
- KJ explicitly starts and ends shows
- Queue belongs to a show; queue resets when a new show starts
- Default show type is an account-level setting on the DJ

---

## TODO

- [x] Queue CRUD (add, remove, reorder)
- [x] "Now playing" state
- [x] KJ manual overrides (bump someone up, skip, remove)
- [ ] Singer history (who sang what, when)
- [ ] Audience-facing queue position / wait estimate
- [ ] Live notifications (Web Push API + in-page fallback)
- [ ] Song suggestions list for KJs
- [x] Manual song entry (for KJs without a catalog / streaming service users)
