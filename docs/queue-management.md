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

## Design Decisions

- [ ] Which rotation styles do we support at launch? (Both? Start with one?)
- [ ] Is rotation style a per-show setting or an account-level default?
- [ ] Can a KJ switch rotation style mid-show?
- [ ] How do we communicate expected wait time to singers?
- [ ] How does the UI differ between rotation styles (if at all)?

---

## TODO

- [ ] Queue CRUD (add, remove, reorder)
- [ ] "Now playing" state
- [ ] Singer history (who sang what, when)
- [ ] KJ manual overrides (bump someone up, skip, remove)
- [ ] Audience-facing queue position / wait estimate
