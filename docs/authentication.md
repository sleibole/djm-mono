# Authentication

## Overview

Authentication is email-based. We optimize for frictionless signup — a new user enters their email, receives a magic link, and clicking it logs them in and confirms their email in one step. No password required to get started.

---

## User Roles

A single `User` model with a role field. One login flow for everyone — the role determines access.

| Role | Description |
|------|-------------|
| **dj** | Paying customer. Manages catalogs, queues, shows. |
| **audience** | Lightweight account. Tracks personal song history (songs sung, favorites, stats). |
| **admin** | Site administration. Access to admin section. |

- An audience member who starts DJing gets their role upgraded — no new account needed
- Audience accounts are just as frictionless as DJ accounts (magic link, no password required)

---

## Signup Flow

```
New User                    Core App                    Email (SES)
   │                          │                           │
   ├── enters email ─────────>│                           │
   │                          ├── create User (unconfirmed)
   │                          ├── generate magic token    │
   │                          ├── send magic link ───────>│
   │<── "Welcome! Check      ─┤                           │
   │     your email to        │                           │
   │     get started"         │                           │
   │                          │       user clicks link    │
   ├── GET /auth/magic/:token ────────────────────────────┤
   │                          │                           │
   │                          ├── validate token          │
   │                          ├── confirm email           │
   │                          ├── create session          │
   │<── logged in, redirect ──┤                           │
```

1. User enters their email on the login page (there is no separate signup page)
2. If the email is new, create a `User` record (unconfirmed)
3. Generate a short-lived magic link token
4. Send email with the magic link via SES
5. User clicks the link → token is validated, email is confirmed, session is created
6. User is logged in and redirected to their dashboard

**There is no separate signup vs login form.** The user enters their email either way:
- **New user** sees: *"Welcome! Check your email to get started."*
- **Existing user** sees: *"Welcome back! Check your email to log in."*

---

## Login Flow (Returning User)

Same as signup:

1. User enters their email
2. Magic link is sent
3. Click → session created

If the user has set a password (see below), they can choose to log in with email + password instead.

---

## Password (Optional)

- By default, users authenticate via magic links only — no password
- Users can **optionally add a password** from their Account page
- Once a password is set, the login page offers both options: magic link or password
- Users can remove their password and go back to magic-link-only

### Account Page

- Accessible from the nav as **"Account"**
- Set or change password
- Update email (triggers re-confirmation via magic link to new address)

---

## Magic Link Details

| Property | Value |
|----------|-------|
| Token format | Secure random token (`SecureRandom.urlsafe_base64(32)`) |
| Token lifetime | 10 minutes |
| Single use | Yes — invalidated after first click |
| Stored as | Hashed in the database (like a password) |

- Tokens are **hashed before storage** — if the DB leaks, tokens are useless
- Expired or already-used tokens show a friendly "This link has expired, request a new one" page
- Generating a new magic link invalidates any previous unused link for that email

---

## Account Locking (Password Only)

- Account locks after **10 consecutive failed password attempts**
- When locked, **password login is disabled** but **magic link login still works**
- A successful magic link login resets the failed attempt counter and unlocks the account
- No timed unlock — the magic link is the unlock mechanism
- This means legitimate users are never truly locked out

---

## Rate Limiting

| Scope | Limit |
|-------|-------|
| Per email | 5 requests per hour |
| Per IP | 10 requests per hour |

- After the limit is hit, show the same message as a normal send (don't reveal the rate limit)
- Implemented via simple counters in Rails cache or DB

---

## Session Management

- Sessions are stored server-side (Rails default session store or DB-backed)
- Session cookie is `HttpOnly`, `Secure`, `SameSite=Lax`

| Role | Session duration |
|------|-----------------|
| **dj** | 30 days |
| **audience** | 30 days |
| **admin** | 24 hours |

---

## Email

- **Production:** AWS SES
- **Development:** [MailHog](https://github.com/mailhog/MailHog) (SMTP on `localhost:1025`, web UI on `localhost:8025`)
- Used for: magic links, email confirmation, password reset (if password is set)

---

## Out of Scope (For Now)

- OAuth / social login
- Two-factor authentication
- Team/org accounts with multiple members
